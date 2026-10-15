"""Original quiet gardening cues, synthesized reproducibly with the standard library."""
from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parent.parent/'assets/audio'
for name,frequency,seconds in [('garden_pick',660,.11),('garden_water',390,.16)]:
 rng=random.Random(912 if name=='garden_pick' else 407);rate=22050;values=[]
 for i in range(int(rate*seconds)):
  t=i/rate;envelope=math.sin(math.pi*t/seconds)**2*math.exp(-t*14)
  tone=math.sin(2*math.pi*(frequency*t-150*t*t))
  sound=(tone*.55+rng.uniform(-1,1)*.12)*envelope*.22
  values.append(struct.pack('<h',round(sound*32767)))
 with wave.open(str(root/(name+'.wav')),'wb') as audio:
  audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(rate);audio.writeframes(b''.join(values))
 print(name+'.wav')
