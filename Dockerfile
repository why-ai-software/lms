FROM frappe/erpnext:v16.19.1

ARG COOLIFY_FQDN
ARG SERVICE_URL_FRAPPE
ARG SERVICE_FQDN_FRAPPE
ARG MYSQL_ROOT_PASSWORD
ARG SITE_NAME
ARG ADMIN_PASSWORD
ARG SERVICE_URL_FRONTEND
ARG SERVICE_FQDN_FRONTEND

USER frappe
WORKDIR /home/frappe/frappe-bench

# Install payments dependency for LMS.
# Use develop because payments does not currently have a normal version-16 branch.
RUN set -eux; \
    bench get-app https://github.com/frappe/payments.git --branch develop

# Copy this repository as the LMS app.
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms

# Install Python requirements for LMS and build assets.
RUN set -eux; \
    pip install -e /home/frappe/frappe-bench/apps/lms; \
    bench build --app lms

USER frappe
WORKDIR /home/frappe/frappe-bench