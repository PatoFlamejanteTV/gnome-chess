# small script to easuly build the app

cd .. # dumb bugfix
flatpak run org.flatpak.Builder --force-clean --install --repo=./repo ./build ./gnome-chess/org.gnome.Chess.json --user
#                                                                             our path                           needed to make
#                                                                                                           flatpak shut the fuck up
#                                                                                                         due to some weird permission
#                                                                                                           needed to use some paths
