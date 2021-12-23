# nt-cpp-tools
Experimental treesitter based neovim plugin to create intelligent implementations for C++

## Features

1. Out-of class member function implementation
2. Concrete class implement from Abstract class or Interface

## Usage

* Select the range of the class using visual mode
* Use below commands

| Command      | Feature |
| ----------- | ----------- |
| `TSCppDefineClassFunc`      | Implement out of class member function    |
| `TSCppMakeConcreteClass`   | Create a concrete class implementing all the pure virtual functions        |
