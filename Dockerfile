ARG base_repo=python
ARG base_tag=3.11-alpine
ARG builder_repo=ghcr.io/fullctl/fullctl-builder-alpine
ARG builder_tag=prep-release

ARG virtual_env=/venv
ARG install_to=/srv/service
ARG build_deps=" \
    g++ \
    git \
    libffi-dev \
    libjpeg-turbo-dev \
    linux-headers \
    make \
    openssl-dev \
    curl \
    rust \
    cargo \
    "
ARG run_deps=" \
    libgcc \
    "
ARG uid=6300
ARG user=fullctl

FROM ${base_repo}:${base_tag} as base

ARG virtual_env
ARG install_to

ENV SERVICE_HOME=$install_to
ENV VIRTUAL_ENV=$virtual_env
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


# build container
FROM $builder_repo:$builder_tag as builder

# individual files here instead of COPY . . for caching
COPY pyproject.toml poetry.lock ./

# Need to upgrade pip and wheel within Poetry for all its installs
RUN poetry install --no-root

COPY Ctl/VERSION Ctl/

#### final image

FROM base as final

ARG run_deps
ARG uid
ARG user

# add dependencies
RUN apk --update --no-cache add $run_deps

RUN adduser -Du $uid $user

WORKDIR $SERVICE_HOME
COPY --from=builder "$VIRTUAL_ENV" "$VIRTUAL_ENV"

COPY Ctl/VERSION etc/
COPY docs/ docs

#### entry point from final image, not tester
FROM final

ARG uid

COPY src/ main/
COPY Ctl/docker/entrypoint.sh .
RUN ln -s $SERVICE_HOME/entrypoint.sh /entrypoint
RUN ln -s /venv $SERVICE_HOME/venv

USER $uid

ENTRYPOINT ["/entrypoint"]
CMD ["uvicorn", "main:app", "--app-dir=src/regctl/api", "--host", "0.0.0.0", "--port", "8000"]