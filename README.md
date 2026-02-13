# rbx-instance-serializer
**WARNING:** Im rewriting the project so its currently not usable, and as there's probably 0 people even seeing this currently, i wont even bother me setting the main branch with the old usable code and keep working with the new code in another branch; The project is much more clean and maintanable now so if anyone wants to spend some time to help create the only and best instance binary serializer for Roblox feel free to do so.

A blazing fast and size-efficient Roblox instance serializer.

## Benchmarks

- Up to 80% smaller than common serialization methods on heavy models
- Around 41% smaller than .rbxm files
- Serializes the entire Brookhaven map (9,797 instances) in ~0.054s

*Speed tests made on a I7 12000h CPU*

## Perks
- Versioning - new BrickPack library versions can deserialize very old files.
- Compression - DeFlate & ZLib support.
- Effectiveness - optimizations for similar instances, properties with default values.
- Script support - emulates scripts instances
