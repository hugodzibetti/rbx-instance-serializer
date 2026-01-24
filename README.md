# rbx-instance-serializer
A blazing fast & size effective Roblox instance serializer.

**WARN:** I made that project in under 8 hours and it's missing the deserialization function, i will add it soon.

# Benchmarks
Output is up to *80%* smaller than the most common serialization method on heavy models, and **41%** smaller than you would get by saving a heavy model to a .rbxm file in Roblox Studio.

Testing on my laptop it could serialize the entire Brookhaven Map(9797 instances) within ~0.054s.

I still didn't measured the speed againts the "loadstring" serialization/deserialization method but **it's at least 100x faster**, considering most plugins that use this common method of serialization usually take a couple seconds to serialize hundred of instances and just take forever to do a thousand instances.