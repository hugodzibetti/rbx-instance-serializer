# luau-go
Executes the given function in a separate thread, threads are pooled and reused.

## Tip
It runs faster than `task.spawn` if the thread doesn't yield (The more non-yielding threads you can make `go`, the more threads you can reuse.)

## Features
- Very small and simple module, useful for optimizing `task.spawn` by reusing threads.
- Original: [util.luau/threadpool](https://github.com/lukadev-0/util.luau/blob/main/packages/threadpool/init.luau)
- Supports executing functions in separate threads and reusing threads
- Supports various lua environments (luau, lune, and roblox)

## Installation
### From pesde
```sh
pesde add jiwonz/go
```

# Example Usage
```luau
local t: thread = go(function()
	...
end)
```
