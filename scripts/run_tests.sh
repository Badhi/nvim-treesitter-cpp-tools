#!/bin/bash
nvim --headless --noplugin -u ./scripts/minimal_setup.lua -c "PlenaryBustedDirectory ./ { minimal_init = './scripts/minimal_setup.lua'}" 
