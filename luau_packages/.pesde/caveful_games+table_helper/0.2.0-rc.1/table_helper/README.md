# [table-helper-luau](https://pesde.dev/packages/caveful_games/table_helper)
A collection of helpful table utility functions extending [TableUtil](https://sleitnick.github.io/RbxUtil/api/TableUtil/) from [RbxUtil](https://github.com/Sleitnick/RbxUtil) for luau

## Installation
via pesde
```sh
pesde add caveful_games/table_helper
```

### Note
This library is zero dependency. so this can be installed via git submodule or also vendoring works fine.

## TO-DOs
- [ ] Publish for Roblox (Setup multitarget)
- [x] Add `tableHelper.Deleted`
- [x] Add Roblox-specific utilities (related to `HttpServer:JSONEn/Decode` like RbxUtil's TableUtil and list of `Player`s)
- [ ] Add docs through moonwave (Generate into markdown and publish)

## Credits
- [Sleitnick/RbxUtil/TableUtil](https://github.com/Sleitnick/RbxUtil/blob/main/modules/table-util/init.luau) - Original table utility functions
- [ffrostfall's luausignal](https://github.com/ffrostfall/luausignal/blob/77d6d8ace5809c5f3bd8b3417472a7130fd82c80/src/init.luau#L213) - `tableHelper.Deleted` was heavily inspired by its `errorTable`
