#To install,
sudo rm -rf /opt/nvim
sudo rm -rf /opt/nvim-linux64/
sudo rm -rf $HOME/.config/nvim
sudo rm -rf $HOME/.local/share/nvim
sudo rm -rf $HOME/.local/state/nvim


cd ~/tmp
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo rm -rf /opt/nvim-linux64
sudo tar -C /opt -xzf nvim-linux64.tar.gz

#add path to env, 
export PATH="$PATH:/opt/nvim-linux64/bin"

#copy config file to ~/.config/nvim,
cp init.lua ~/.config/nvim
cp -r ./lua ~/.config/nvim
#install other packages
sudo apt-get install ripgrep  -y
#sudo apt install fd-find (https://github.com/sharkdp/fd)

sudo apt-get install xclip -y