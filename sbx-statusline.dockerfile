# syntax=docker/dockerfile:1
# An overlay carrying exactly one file: the statusline script the install hook
# in sbx-statusline.yaml points settings.json at. The v2 kit shipped it through
# the files/home/ tree convention, which v3 has no equivalent of, so the same
# tree lands through a COPY into a staging stage: files/home/ onto /home/agent/,
# path for path.
#
# WHY A STAGING STAGE FOR ONE FILE. Copying straight into a scratch stage with
# `COPY --chown=1000:1000 files/home/ /home/agent/` is the obvious form and it
# is wrong: BuildKit applies --chown to every parent directory it CREATES, so
# the overlay would ship `/home` itself owned by uid 1000, and an overlay's
# directory entries replace the base's. Staging under /out and chowning only
# /out/home/agent leaves /home root-owned and gives the agent exactly its own
# subtree (SPEC-v3 overlay-home-ownership). Same shape as the git-ssh-sign kit.
#
# The stage is pinned to $BUILDPLATFORM: it only copies and chowns a shell
# script, so it has no reason to run under emulation when the kit is published
# for both linux/amd64 and linux/arm64.
#
# 1000 rather than `agent`: busybox has no passwd entry for the agent user.
#
# --chmod=0755: the script is executed directly by Claude Code's statusLine
# command, and an ordinary OCI layer can carry the executable bit (v2's could
# not, which is why the script used to be re-chmodded by the plugin's sync).
FROM --platform=$BUILDPLATFORM busybox:1.37 AS stage

COPY --chmod=0755 files/home/ /out/home/agent/
RUN chown -R 1000:1000 /out/home/agent

FROM scratch
COPY --from=stage /out /
