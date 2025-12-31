if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export user_name=snarasim
    export code_folder=$HOME/code
    export STARTUP_FOLDER=$HOME
    export TEMP_FOLDER=$HOME/tmp
    export USER_BIN_FOLDER=$HOME/bin
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export user_name=snarasim
    export code_folder=~/Code
    export STARTUP_FOLDER=$HOME
    export TEMP_FOLDER=$HOME/tmp
    export USER_BIN_FOLDER=$HOME/bin
    #poetry_folder=
elif [[ "$OSTYPE" == "msys" ]]; then
    export user_name=snarasim
    export code_folder=~/code
    export STARTUP_FOLDER=$HOME
    export TEMP_FOLDER=$HOME/tmp
    export USER_BIN_FOLDER=$HOME/bin
elif [[ "$OSTYPE" == "cygwin" ]]; then
    export user_name=snarasim
    export code_folder=~/code
    export STARTUP_FOLDER=$HOME
    export TEMP_FOLDER=$HOME/tmp
    export USER_BIN_FOLDER=$HOME/bin
fi
