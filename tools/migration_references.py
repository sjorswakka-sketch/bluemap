"""Explicit, non-executing links in the phase-1 effective catalogs and registry.

This graph is deliberately scoped: arbitrary script-created IDs, runtime spawns,
asset names and algorithmic flag names need phase-5/6/7 export, not guessing.
"""
from __future__ import annotations


class ReferenceError(ValueError):
    pass


def build_references(content: dict, maps: dict) -> dict:
    catalogs = content['catalogs']
    ids = {name: {entry['id'] for entry in data['entries']}
           for name, data in catalogs.items()}
    by_map = {m['id']: m for m in maps['maps']}
    edges = []

    def escaped(value):
        return value.replace('~', '~0').replace('/', '~1')

    def link(owner, path, namespace, target, selection='value'):
        if not isinstance(target, str) or target not in ids[namespace]:
            raise ReferenceError(f'{owner} {path}: unknown {namespace} ID {target!r}')
        edges.append({'source': owner, 'path': path, 'selection': selection,
                      'target': {'namespace': ['catalog', namespace], 'id': target}})

    def item(owner, path, target, specials=()):
        if target in specials:
            # "coins" is the chest currency operation, not an item or pickup ID.
            namespace = ['currency_operation'] if target == 'coins' else ['catalog', 'special_pickups']
            edges.append({'source': owner, 'path': path, 'selection': 'value',
                          'target': {'namespace': namespace, 'id': target}})
        else:
            link(owner, path, 'items', target)

    def dialogue(owner, value, path=''):
        if isinstance(value, list):
            for index, child in enumerate(value):
                dialogue(owner, child, f'{path}/{index}')
        elif isinstance(value, dict):
            for key, child in value.items():
                if key == 'next' and child != '':
                    link(owner, path + '/next', 'talks', child)
                else:
                    dialogue(owner, child, path + '/' + escaped(key))

    for name, catalog in catalogs.items():
        for entry in catalog['entries']:
            owner = {'namespace': ['catalog', name], 'id': entry['id'], 'root': 'entry_value'}
            v = entry.get('value', {})
            if name in {'gear', 'clothes', 'consumables'}:
                link({**owner, 'root': 'entry'}, '/id', 'items', entry['id'])
            if name == 'weapons' and v.get('item'):
                item(owner, '/item', v['item'])
            if name == 'recipes':
                item(owner, '/output', v['output'])
                link(owner, '/skill', 'professions', v['skill'])
                for target in v.get('inputs', {}):
                    link(owner, '/inputs/' + escaped(target), 'items', target, selection='dictionary_key')
                if v.get('upgrade_from'):
                    item(owner, '/upgrade_from', v['upgrade_from'])
            if name == 'resources':
                item(owner, '/item', v['item'])
                link(owner, '/skill', 'professions', v['skill'])
                for index, target in enumerate(v.get('tools', [])):
                    item(owner, '/tools/' + str(index), target)
            if name == 'enemies':
                for index, drop in enumerate(v.get('drops', [])):
                    item(owner, f'/drops/{index}/0', drop[0], ('coin', 'heart'))
            if name == 'npcs':
                for index, rule in enumerate(v.get('rules', [])):
                    if 'talk' in rule:
                        link(owner, f'/rules/{index}/talk', 'talks', rule['talk'])
            if name == 'talks':
                dialogue(owner, v)
            if name == 'shops':
                for index, sale in enumerate(v.get('items', [])):
                    item(owner, f'/items/{index}/item', sale['item'])
                    for n, extra in enumerate(sale.get('with', [])):
                        item(owner, f'/items/{index}/with/{n}/0', extra[0])

    for m in maps['maps']:
        for index, obj in enumerate(m['registry_snapshot']['objects']):
            owner = {'namespace': ['map_slot', m['id']], 'id': str(index), 'root': 'registry_object'}
            link(owner, '/type', 'object_types', obj['type'])
            if obj['type'] == 'npc':
                link(owner, '/id', 'npcs', obj['id'])
            if obj['type'] == 'enemy':
                link(owner, '/kind', 'enemies', obj['kind'])
            if obj['type'] == 'profession_resource':
                link(owner, '/kind', 'resources', obj['kind'])
            if 'talk' in obj:
                link(owner, '/talk', 'talks', obj['talk'])
            if obj['type'] == 'pickup':
                item(owner, '/item', obj['item'], ('coin', 'heart'))
            if obj['type'] == 'chest':
                for n, drop in enumerate(obj['contents']):
                    item(owner, f'/contents/{n}/0', drop[0], ('coins',))
            if obj['type'] == 'portal':
                link(owner, '/to', 'maps', obj['to'])
                spawn = obj.get('spawn', 'start')
                if spawn not in by_map[obj['to']]['registry_snapshot']['spawns']:
                    raise ReferenceError(f'{m["id"]} slot {index}: missing destination spawn {spawn!r}')
                edges.append({'source': owner, 'path': '/spawn', 'selection': 'value',
                              'target': {'namespace': ['map_spawn', obj['to']], 'id': spawn}})
        for node in m['post_registry_legacy_resources']:
            owner = {'namespace': ['profession_cooldown'], 'id': node['id'], 'root': 'post_registry_resource_value'}
            link(owner, '/kind', 'resources', node['value']['kind'])
    return {'schema': 'bluemap.portable.references.v1',
            'scope': 'explicit_effective_catalog_and_registry_links_only',
            'notRuntimeExport': True, 'count': len(edges), 'edges': edges,
            'pathContract': 'RFC6901 JSON pointer relative to source.root; selection=dictionary_key selects the final key instead of its stored value. An omitted portal spawn denotes its explicit legacy default start.',
            'deferred': ['operation arguments in rules.json', 'runtime-added map objects',
                         'algorithmic flags and spawn IDs', 'graphics and audio resource resolution']}
