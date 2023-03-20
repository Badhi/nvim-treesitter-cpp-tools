# nt-cpp-tools
![Unit Tests](https://github.com/badhi/nvim-treesitter-cpp-tools/actions/workflows/unit_tests.yml/badge.svg)

Experimental treesitter based neovim plugin to create intelligent implementations for C++

## Features

1. Out-of class member function implementation
2. Concrete class implement from Abstract class or Interface
3. Add missing functions to obey Rule of 3
4. Add missing functions to obey Rule of 5

## Install

Using [paq](https://github.com/savq/paq-nvim)

```lua
require "paq" {
    "nvim-treesitter/nvim-treesitter",
    "Badhi/nvim-treesitter-cpp-tools",
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    requires = { "nvim-treesitter/nvim-treesitter" },
    "Badhi/nvim-treesitter-cpp-tools",
}
```

## Setup

Add the following config to your init script

==Note : The config for this plugin, included in the `treesitter.config` is now moved to an independent config. Please make required changes==

```lua
require('nt-cpp-tools.config').setup({
      preview = {
          quit = 'q', -- optional keymapping for quit preview
          accept = '<tab>' -- optional keymapping for accept preview
      },
      header_extension = 'h', -- optional
      source_extension = 'cxx', -- optional
      custom_define_class_function_commands = { -- optional
          TSCppImplWrite = {
              output_handle = require'nvim-treesitter.nt-cpp-tools.output_handlers'.get_add_to_cpp()
          }
          --[[
          <your impl function custom command name> = {
              output_handle = function (str, context) 
                  -- string contains the class implementation
                  -- do whatever you want to do with it
              end
          }
          ]]
      }
})
```

## Usage

* Select the range of the class using visual mode
* Use below commands

| Command      | Feature |
| ----------- | ----------- |
| `TSCppDefineClassFunc`      | Implement out of class member functions<br><br> *subset of functions can be implemented by selecting required function declarations using visual mode or simply keeping the cursor on the function declaration before calling the command*<br><br>Supported special features<br>1. Templates (with default args)<br>2. Function arguments with default values<br>3. Nested classes<br>(check [test_cases](https://github.com/Badhi/nvim-treesitter-cpp-tools/blob/master/test/implement_functions.txt) for tested  examples)|
| `TSCppMakeConcreteClass`   | Create a concrete class implementing all the pure virtual functions        |
| `TSCppRuleOf3`   | Adds the missing function declarations to the class to obey the Rule of 3 (if eligible)        |
| `TSCppRuleOf5`   | Adds the missing function declarations to the class to obey the Rule of 5 (if eligible)        |


## Example

1. `TSCppDefineClassFunc`

![TSImplementFunc](https://user-images.githubusercontent.com/10277051/152277748-d7c0204a-b54e-4ae1-90ac-b1e4cbd51ba5.gif)

2. `TSCppMakeConcreteClass`

![TSConcreteClass](https://user-images.githubusercontent.com/10277051/152278222-d20e34f0-542d-451e-ae16-646f68e9f72f.gif)

3. `TSCppRuleOf3`

![TSRuleOf3](https://user-images.githubusercontent.com/10277051/152277800-a2573916-5e8a-4f3a-804f-88f6f6994281.gif)

