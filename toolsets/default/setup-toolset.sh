#!/bin/bash

# path setup
case $HAM_OS in
    NT*)
        . ham-toolset-import.sh msvc_10_x86
        ;;
    *)
        echo "E/Toolset: Unsupported host OS"
        return 1
        ;;
esac