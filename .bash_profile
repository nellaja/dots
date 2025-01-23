#
# ~/.bash_profile
#

# Initial export to insert user bin as first path upon system login
export PATH=~/bin:$PATH

# Disable history logging for bash shell
export HISTSIZE=19

# Make /tmp directory in home folder
mkdir -p ~/tmp

# Start Sway
sway-run
