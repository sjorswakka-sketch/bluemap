using System;
using UnityEngine;
namespace BlueMapMigration.Player
{
    // Original camera VIEW and zoom. Coordinates remain Godot pixels until projection.
    public static class PlayerCameraMath
    {
        public static readonly Vector2 View = new Vector2(576, 324);
        public static Vector2 Clamp(Vector2 position, int width, int height)
        {
            Vector2 pixels = new Vector2(width * 32, height * 32), half = View * .5f;
            return new Vector2(pixels.x <= View.x ? pixels.x * .5f : Mathf.Clamp(position.x, half.x, pixels.x-half.x),
                pixels.y <= View.y ? pixels.y * .5f : Mathf.Clamp(position.y, half.y, pixels.y-half.y));
        }
        public static Vector2 Follow(Vector2 current, Vector2 target, double delta)
            => current + (target-current) * Mathf.Clamp01((float)(5 * delta));
    }
    public sealed class PlayerAimModel
    {
        private Vector2 retainedStick;
        public Vector2 Direction { get; private set; } = Vector2.up;
        public Vector2 Position { get; private set; }
        public void DeviceChanged() { retainedStick = Vector2.zero; }
        public void Update(Vector2 player, Vector2 facing, Vector2 movement, Vector2 stick,
            bool controller, bool mouseActive, Vector2 mouseWorld, bool locked)
        {
            if (locked) return;
            Direction = facing;
            if (controller)
            {
                if (stick.sqrMagnitude > .01f) retainedStick = PlayerMotorModel.NormalizeSource(stick);
                else if (PlayerMotorModel.HasSourceInput(movement)) retainedStick = Vector2.zero;
                if (retainedStick != Vector2.zero) Direction = retainedStick;
                Position = player + Direction * 90;
            }
            else if (mouseActive)
            {
                Position = mouseWorld; Vector2 difference = Position-player;
                if (difference.sqrMagnitude > 16) Direction = PlayerMotorModel.NormalizeSource(difference);
            }
            else Position = player + Direction * 90;
        }
    }
}