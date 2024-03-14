if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export user_name=snarasim
    export code_folder=$HOME/code
    export STARTUP_FOLDER=$HOME
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export user_name=snarasim
    export code_folder=~/Code
    export STARTUP_FOLDER=$HOME
    #poetry_folder=
elif [[ "$OSTYPE" == "msys" ]]; then
    export user_name=snarasim
    export code_folder=~/code
    export STARTUP_FOLDER=$HOME
elif [[ "$OSTYPE" == "cygwin" ]]; then
    export user_name=snarasim
    export code_folder=~/code
    export STARTUP_FOLDER=$HOME
fi
