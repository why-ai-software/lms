FROM frappe/erpnext:v16.19.1

USER frappe
WORKDIR /home/frappe/frappe-bench

RUN set -eux; \
    bench get-app https://github.com/frappe/payments.git --branch version-16; \
    bench get-app https://github.com/frappe/lms.git --branch main; \
    bench build

USER frappe
WORKDIR /home/frappe/frappe-bench