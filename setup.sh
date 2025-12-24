# initial setup for building, testing, etc.


# small note here that it uses kinda a lot of space, but remember that mostly
# of them are due to SDKs and libs, so you only need to install once
# and them you can just build any oher GNOME app without installing it again

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.flatpak.Builder
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
flatpak install gnome-nightly org.gnome.Platform//master
flatpak install gnome-nightly org.gnome.Sdk//master

echo "-+-+-+-+-+-+-+-+-+-+-"
echo "[SUCCESS] Setup completed!"
echo "-+-+-+-+-+-+-+-+-+-+-"