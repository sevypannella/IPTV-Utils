# IPTV-Utils
collection de script bash (linux) pour fichiers M3U

Comme j'en avait marre de jongler avec les urls pour obtenir les playlists et les mettre à jours, j'ai décidé de créer un script bash.

#### Logiciel requis:
requiere wget, curl ffmpeg, ffprobe et jq

## Get-Playlist
Script pour obtenir la playlist à partir d'une url type http://host.domain:port/user/password/channel ou http://host.domain:port/live|movie/user/password/channel

### usage:
get-playlist.sh http://host.domain/user/password/channel

Fichier de sortie: playlist_host.domain-MM-DD-YYYY.m3u

#### ToDo-List
ajouter des options pour:
juste afficher l'url
Consulter les info du compte en local
...

## M3U-Optimizer

A venir
