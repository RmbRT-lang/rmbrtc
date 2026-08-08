# Locate the OS project.
RLOS=`rmbrtbc --find ../os`
if [ -z "$RLOS" ]; then
	echo "Could not find 'os'!"
	exit 1
else
	echo "[DEP  ] os: $RLOS"
fi

# Find the .o and .rl files.
RLOS_O="$(find /tmp$RLOS -name "*.o")"

RLOS_RL=`find $RLOS -name "*.rl"`
echo "RL: " "$RLOS_RL"
if [ -z "$RLOS_O" ]; then
	echo "Please compile the OS first: could not find any .o files for it"
	exit 1
else
	echo "[LIB  ] os: $RLOS_O"
fi

RLC_RL=`find src -name "*.rl"`

echo compiling...
RL_LINK_LIBRARIES=$RLOS_O
RL_LINK_LIBRARIES=$RL_LINK_LIBRARIES
echo RL_LINK_LIBRARIES="$RL_LINK_LIBRARIES" rmbrtbc --run src/main.rl $RLOS_RL

PWD_SAVE=`realpath $PWD`
mkdir -p /tmp/.rlc-exe/$PWD_SAVE
if [ ! -L a.out ]; then
	ln -s "/tmp/.rlc-exe/$PWD_SAVE/a.out" a.out
fi
cd /tmp/.rlc-exe/$PWD_SAVE
RL_LINK_LIBRARIES="$RL_LINK_LIBRARIES" rmbrtbc $PWD_SAVE/src/main.rl $RLOS_RL && cd $PWD_SAVE && RLC_ST=0 ./a.out src/main.rl $RLOS_RL : out
