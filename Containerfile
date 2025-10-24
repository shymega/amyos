FROM scratch AS ctx
COPY build_files /

# ZFS kernel and module
FROM ghcr.io/ublue-os/akmods-zfs:coreos-testing-42 AS zfs-cache

FROM ghcr.io/ublue-os/bazzite:42 as amyos
COPY system_files /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=zfs-cache,src=/kernel-rpms,dst=/tmp/rpms/kernel \
    --mount=type=bind,from=zfs-cache,src=/rpms/kmods/zfs,dst=/tmp/rpms/zfs \
    /ctx/install-apps.sh && \
    /ctx/fix-opt.sh && \
    /ctx/build-initramfs.sh && \
    /ctx/cleanup.sh
