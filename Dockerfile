FROM frappe/erpnext:v16.19.1

ARG COOLIFY_FQDN
ARG SERVICE_URL_FRAPPE
ARG SERVICE_FQDN_FRAPPE
ARG MYSQL_ROOT_PASSWORD
ARG SITE_NAME
ARG ADMIN_PASSWORD
ARG SERVICE_URL_FRONTEND
ARG SERVICE_FQDN_FRONTEND
ARG COOLIFY_BUILD_SECRETS_HASH

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libcairo2 \
    libcairo2-dev \
    && rm -rf /var/lib/apt/lists/*

USER frappe
WORKDIR /home/frappe/frappe-bench

# Debug versions in Coolify logs
RUN node --version && yarn --version && python --version && bench --version

# Install payments dependency for LMS.
# For Frappe v16 / LMS, payments develop is currently safer than version-16.
RUN bench get-app https://github.com/frappe/payments.git --branch develop

# Copy this repository as the LMS app.
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms

# Register LMS in bench apps list.
# COPY does not do what "bench get-app" normally does.
RUN set -eux; \
    grep -qxF "lms" sites/apps.txt || echo "lms" >> sites/apps.txt; \
    cat sites/apps.txt

# If Coolify did not clone git submodules, clone frappe-ui manually.
RUN set -eux; \
    if [ ! -f /home/frappe/frappe-bench/apps/lms/frappe-ui/package.json ]; then \
      echo "frappe-ui submodule missing, cloning it manually..."; \
      rm -rf /home/frappe/frappe-bench/apps/lms/frappe-ui; \
      git clone https://github.com/frappe/frappe-ui /home/frappe/frappe-bench/apps/lms/frappe-ui; \
    else \
      echo "frappe-ui exists."; \
    fi

# Install LMS into the actual bench virtualenv.
RUN /home/frappe/frappe-bench/env/bin/pip install -e /home/frappe/frappe-bench/apps/lms

# Validate that the runtime Python can import LMS.
RUN /home/frappe/frappe-bench/env/bin/python -c "import lms; print('LMS import OK:', lms.__file__)"

# Validate required LMS frontend files.
RUN set -eux; \
    test -f /home/frappe/frappe-bench/apps/lms/package.json; \
    test -f /home/frappe/frappe-bench/apps/lms/frontend/package.json; \
    test -f /home/frappe/frappe-bench/apps/lms/frontend/vite.config.js; \
    node --version; \
    yarn --version

# Build LMS frontend explicitly.
# We do this instead of "bench build --app lms" because Coolify was hiding the real build error.
RUN set -eux; \
    cd /home/frappe/frappe-bench/apps/lms; \
    yarn install --check-files --network-timeout 100000 --ignore-engines; \
    cd /home/frappe/frappe-bench/apps/lms/frontend; \
    yarn install --check-files --network-timeout 100000 --ignore-engines; \
    yarn build

USER frappe
WORKDIR /home/frappe/frappe-bench