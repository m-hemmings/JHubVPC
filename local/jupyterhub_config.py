import os
from dockerspawner import DockerSpawner
from nativeauthenticator import NativeAuthenticator

c.JupyterHub.authenticator_class = NativeAuthenticator
c.Authenticator.admin_users = {"admin"}
c.NativeAuthenticator.open_signup = True

c.JupyterHub.spawner_class = DockerSpawner

network_name = os.environ.get("DOCKER_NETWORK_NAME", "bridge")
c.DockerSpawner.network_name = network_name
c.DockerSpawner.remove = True

# Persist user home dirs in named volumes
c.DockerSpawner.volumes = {
    "jhub-user-{username}": "/home/jovyan"
}

datasci_image = os.environ["DATASCI_IMAGE"]
desktop_image = os.environ["DESKTOP_IMAGE"]

c.DockerSpawner.allowed_images = {
    "Data Science (JupyterLab + VS Code + RStudio)": datasci_image,
    "Linux Desktop (XFCE + noVNC)": desktop_image,
}
c.DockerSpawner.image = datasci_image

# Per-image env
def pre_spawn_hook(spawner):
    if spawner.image == desktop_image:
        spawner.environment.update({
            "VNC_PW": os.environ.get("VNC_PW", "changeme"),
            "VNC_RESOLUTION": os.environ.get("VNC_RESOLUTION", "1600x900"),
            "VNC_COL_DEPTH": os.environ.get("VNC_COL_DEPTH", "24"),
        })

c.Spawner.pre_spawn_hook = pre_spawn_hook

c.JupyterHub.hub_bind_url = "http://0.0.0.0:8081"
c.JupyterHub.hub_connect_url = "http://hub:8081"
