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
# payments currently does not have the same stable version-16 branch flow as Frappe/ERPNext,
# so develop is safer for Frappe v16/LMS right now.
RUN bench get-app https://github.com/frappe/payments.git --branch develop

# Copy this repository as the LMS app.
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms

# Register LMS in bench apps list.
# This is needed because COPY does not behave like "bench get-app".
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

# IMPORTANT:
# Install LMS into the actual bench virtualenv.
# Do not use plain "pip install", because runtime uses /home/frappe/frappe-bench/env.
RUN /home/frappe/frappe-bench/env/bin/pip install -e /home/frappe/frappe-bench/apps/lms

# Validate that the runtime Python can import LMS.
RUN /home/frappe/frappe-bench/env/bin/python -c "import lms; print('LMS import OK:', lms.__file__)"

# Build LMS assets.
RUN set -eux; \
    bench build --app lms

USER frappe
WORKDIR /home/frappe/frappe-bench