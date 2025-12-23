# GNOME Chess

GNOME Chess is a 2D chess game, where games can be played between a combination of human and computer players.
GNOME Chess detects known third party chess engines for computer players.

<a href='https://flathub.org/apps/details/org.gnome.Chess'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-i-en.png'/></a>

## Building GNOME Chess

In order to build the program, we can use [Flatpak](https://docs.flatpak.org/en/latest/introduction.html) and [Flatpak Builder](https://docs.flatpak.org/en/latest/flatpak-builder.html).

First, you need to setup GNOME and Flatpak, install them with:

```bash
./setup.sh # installs everything needed
```

Then build with:

```bash
./build.sh # build using flatpak
```

And run with:

```bash
./run.sh # run org.Gnome.Chess, in this case, my modified version
```

## Useful links
- Report issues: <https://gitlab.gnome.org/GNOME/gnome-chess/issues/>
- Donate: <https://www.gnome.org/friends/>
