CREATE DATABASE IF NOT EXISTS `tenants`;
CREATE DATABASE IF NOT EXISTS `messagegateway`;
CREATE DATABASE IF NOT EXISTS `rhino`;
CREATE DATABASE IF NOT EXISTS `gorilla`;
CREATE DATABASE IF NOT EXISTS `lion`;
CREATE DATABASE IF NOT EXISTS `identity_account_mapper`;
CREATE DATABASE IF NOT EXISTS `voucher_management`;

CREATE USER `mifos`@`%` IDENTIFIED BY `password`;

GRANT ALL PRIVILEGES ON `tenants`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `messagegateway`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `rhino`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `gorilla`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `lion`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `identity_account_mapper`.* TO 'mifos';
GRANT ALL PRIVILEGES ON `voucher_management`.* TO 'mifos';

FLUSH PRIVILEGES;