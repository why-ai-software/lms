FROM frappe/erpnext:v16.19.1

ARG COOLIFY_FQDN
ARG SERVICE_URL_FRAPPE
ARG SERVICE_FQDN_FRAPPE
ARG MYSQL_ROOT_PASSWORD
ARG SITE_NAME
ARG ADMIN_PASSWORD
ARG SERVICE_URL_FRONTEND
ARG SERVICE_FQDN_FRONTEND

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
RUN bench get-app https://github.com/frappe/payments.git --branch develop

# Copy current repo as LMS app.
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms

# Register LMS app in bench, because COPY does not do what bench get-app normally does.
RUN set -eux; \
    grep -qxF "lms" sites/apps.txt || echo "lms" >> sites/apps.txt; \
    cat sites/apps.txt

# Safety: if Coolify did not clone git submodules, clone frappe-ui manually.
RUN set -eux; \
    if [ ! -f /home/frappe/frappe-bench/apps/lms/frappe-ui/package.json ]; then \
      echo "frappe-ui submodule missing, cloning it manually..."; \
      rm -rf /home/frappe/frappe-bench/apps/lms/frappe-ui; \
      git clone https://github.com/frappe/frappe-ui /home/frappe/frappe-bench/apps/lms/frappe-ui; \
    else \
      echo "frappe-ui exists."; \
    fi

# Install LMS Python package.
RUN pip install -e /home/frappe/frappe-bench/apps/lms

# Build LMS assets with better error visibility.
RUN set -eux; \
    bench build --app lms 2>&1 | tee /tmp/lms-build.log || \
    (echo "===== LMS BUILD FAILED ====="; cat /tmp/lms-build.log; exit 1)

USER frappe
WORKDIR /home/frappe/frappe-bench