-- Team: HDL Operations
-- Lab 2: ERD to Physical Relational Schema (SQLite)
-- No triggers used per lab requirements.
--
-- PART B - Rules deferred to Lab 3 triggers:
--   1. Only one active membership per customer at a time
--   2. Only one preferred address per customer
--   3. Rental unit cannot appear on overlapping active contracts
--   4. Only one active manager per store at a time
--   5. Service ticket must target a rental unit XOR a customer item (not both, not neither)
--   6. Return quantity cannot exceed original sale line quantity
--   7. Every sale must have at least one SaleLineItem
--   8. Every rental contract must have at least one ContractRentalUnit

PRAGMA foreign_keys = ON;

-- ============================================================
-- DROP TABLES (leaf-to-root)
-- ============================================================

DROP TABLE IF EXISTS RentalReturn;
DROP TABLE IF EXISTS ServiceInvoice;
DROP TABLE IF EXISTS ServiceTicket;
DROP TABLE IF EXISTS CustomerOwnedItem;
DROP TABLE IF EXISTS SessionInstructor;
DROP TABLE IF EXISTS Enrollment;
DROP TABLE IF EXISTS Session;
DROP TABLE IF EXISTS RentalUnitTransfer;
DROP TABLE IF EXISTS ContractExtension;
DROP TABLE IF EXISTS ContractRentalUnit;
DROP TABLE IF EXISTS RentalContract;
DROP TABLE IF EXISTS ReturnLineItem;
DROP TABLE IF EXISTS ReturnTransaction;
DROP TABLE IF EXISTS SaleLineItem;
DROP TABLE IF EXISTS SalesTransaction;
DROP TABLE IF EXISTS CustomerMembership;
DROP TABLE IF EXISTS Membership;
DROP TABLE IF EXISTS CustomerAddress;
DROP TABLE IF EXISTS StoreVendor;
DROP TABLE IF EXISTS EmployeeStore;
DROP TABLE IF EXISTS VendorProduct;
DROP TABLE IF EXISTS ProductVariant;
DROP TABLE IF EXISTS Product;
DROP TABLE IF EXISTS Vendor;
DROP TABLE IF EXISTS StoreManagerAssignment;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS RentalUnit;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Storefront;

-- ============================================================
-- SCHEMA
-- ============================================================

CREATE TABLE Storefront (
  storeId         INTEGER PRIMARY KEY,
  physicalAddress TEXT    NOT NULL,
  phoneNumber     TEXT    NOT NULL
);

-- employeeId doubles as badge number.
-- specification maps to ERD Employee.Specification attribute.
-- RESTRICT on homeStoreId so a store can't be deleted while employees are assigned.
CREATE TABLE Employee (
  employeeId    INTEGER PRIMARY KEY,
  role          TEXT    NOT NULL,
  hireDate      TEXT    NOT NULL,
  hourlyRate    NUMERIC NOT NULL,
  activeStatus  INTEGER NOT NULL DEFAULT 1,
  homeStoreId   INTEGER NOT NULL,
  specification TEXT,
  CONSTRAINT chkEmployeeRole         CHECK (role IN ('Sales','Repair Tech','Trainer','Manager')),
  CONSTRAINT chkEmployeeHourlyRate   CHECK (hourlyRate >= 0),
  CONSTRAINT chkEmployeeActiveStatus CHECK (activeStatus IN (0,1)),
  CONSTRAINT fkEmployeeHomeStore
    FOREIGN KEY (homeStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Resolves M:N Storefront-Employee (pickup shifts at non-home stores).
CREATE TABLE EmployeeStore (
  storeId    INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  position   TEXT,
  PRIMARY KEY (storeId, employeeId),
  CONSTRAINT fkEmployeeStoreStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkEmployeeStoreEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tracks full manager assignment history. Composite PK allows re-assignment after a gap.
-- Enforcing one active manager per store at a time is deferred to Lab 3 (rule 4).
CREATE TABLE StoreManagerAssignment (
  storeId    INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  startDate  TEXT    NOT NULL,
  endDate    TEXT,
  PRIMARY KEY (storeId, employeeId, startDate),
  CONSTRAINT chkManagerDates CHECK (endDate IS NULL OR endDate >= startDate),
  CONSTRAINT fkManagerStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkManagerEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Vendor (
  vendorId         INTEGER PRIMARY KEY,
  name             TEXT    NOT NULL,
  physicalLocation TEXT
);

-- Resolves M:N Storefront-Vendor.
CREATE TABLE StoreVendor (
  vendorId INTEGER NOT NULL,
  storeId  INTEGER NOT NULL,
  PRIMARY KEY (vendorId, storeId),
  CONSTRAINT fkStoreVendorVendor
    FOREIGN KEY (vendorId) REFERENCES Vendor(vendorId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkStoreVendorStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- sku = Retail_SKU from ERD; base price lives here, variants may override.
CREATE TABLE Product (
  productId     INTEGER PRIMARY KEY,
  sku           TEXT    NOT NULL,
  name          TEXT    NOT NULL,
  brand         TEXT,
  category      TEXT    NOT NULL,
  standardPrice NUMERIC NOT NULL,
  taxStatus     TEXT    NOT NULL,
  activeStatus  INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT uqProductSku            UNIQUE (sku),
  CONSTRAINT chkProductStandardPrice CHECK (standardPrice >= 0),
  CONSTRAINT chkProductTaxStatus     CHECK (taxStatus IN ('Taxable','NonTaxable')),
  CONSTRAINT chkProductActiveStatus  CHECK (activeStatus IN (0,1))
);

CREATE TABLE ProductVariant (
  barcodeId         TEXT    PRIMARY KEY,
  productId         INTEGER NOT NULL,
  variantDescriptor TEXT,
  unitPrice         NUMERIC NOT NULL,
  activeStatus      INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT chkVariantUnitPrice    CHECK (unitPrice >= 0),
  CONSTRAINT chkVariantActiveStatus CHECK (activeStatus IN (0,1)),
  CONSTRAINT fkVariantProduct
    FOREIGN KEY (productId) REFERENCES Product(productId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- Resolves M:N Vendor-Product; stores vendor-specific cost and lead time.
-- RESTRICT on productId: clear vendor records before retiring a product.
CREATE TABLE VendorProduct (
  vendorId     INTEGER NOT NULL,
  productId    INTEGER NOT NULL,
  vendorSku    TEXT,
  unitCost     NUMERIC NOT NULL,
  leadTimeDays INTEGER,
  PRIMARY KEY (vendorId, productId),
  CONSTRAINT chkVendorProductUnitCost     CHECK (unitCost >= 0),
  CONSTRAINT chkVendorProductLeadTimeDays CHECK (leadTimeDays >= 0),
  CONSTRAINT fkVendorProductVendor
    FOREIGN KEY (vendorId) REFERENCES Vendor(vendorId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkVendorProductProduct
    FOREIGN KEY (productId) REFERENCES Product(productId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- membershipFlag (bool) reflects ERD Customer.Membership_ID (bool) attribute.
-- Full membership detail tracked via CustomerMembership bridge table.
CREATE TABLE Customer (
  customerId     INTEGER PRIMARY KEY,
  name           TEXT    NOT NULL,
  phoneNumber    TEXT,
  emailAddress   TEXT,
  creationDate   TEXT    NOT NULL DEFAULT (date('now')),
  membershipFlag INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT chkCustomerMembershipFlag CHECK (membershipFlag IN (0,1))
);

-- One preferred address per customer deferred to Lab 3 (rule 2).
CREATE TABLE CustomerAddress (
  addressId     INTEGER PRIMARY KEY,
  customerId    INTEGER NOT NULL,
  addressString TEXT    NOT NULL,
  isPreferred   INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT chkAddressIsPreferred CHECK (isPreferred IN (0,1)),
  CONSTRAINT fkAddressCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Membership (
  membershipId INTEGER PRIMARY KEY,
  tierName     TEXT    NOT NULL,
  cost         NUMERIC NOT NULL,
  CONSTRAINT chkMembershipCost CHECK (cost >= 0)
);

-- One active membership per customer deferred to Lab 3 (rule 1).
CREATE TABLE CustomerMembership (
  customerMembershipId INTEGER PRIMARY KEY,
  customerId           INTEGER NOT NULL,
  membershipId         INTEGER NOT NULL,
  startDate            TEXT    NOT NULL,
  endDate              TEXT,
  isActive             INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT chkCustomerMembershipDates    CHECK (endDate IS NULL OR endDate >= startDate),
  CONSTRAINT chkCustomerMembershipIsActive CHECK (isActive IN (0,1)),
  CONSTRAINT fkCustomerMembershipCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkCustomerMembershipMembership
    FOREIGN KEY (membershipId) REFERENCES Membership(membershipId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- membershipId (nullable) maps to ERD Transaction.Membership_ID (nullable).
-- Records which membership tier, if any, was applied at time of sale.
-- RESTRICT on all FKs: financial records must outlive store/customer/employee deletions.
CREATE TABLE SalesTransaction (
  transactionId INTEGER PRIMARY KEY,
  dateTime      TEXT    NOT NULL DEFAULT (datetime('now')),
  discount      NUMERIC NOT NULL DEFAULT 0,
  taxedTotal    NUMERIC NOT NULL,
  storeId       INTEGER NOT NULL,
  customerId    INTEGER NOT NULL,
  employeeId    INTEGER NOT NULL,
  membershipId  INTEGER,
  CONSTRAINT chkTransactionDiscount   CHECK (discount >= 0),
  CONSTRAINT chkTransactionTaxedTotal CHECK (taxedTotal >= 0),
  CONSTRAINT fkTransactionStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkTransactionCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkTransactionEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkTransactionMembership
    FOREIGN KEY (membershipId) REFERENCES Membership(membershipId)
      ON DELETE SET NULL ON UPDATE CASCADE
);

-- Minimum one line per transaction enforced in Lab 3 (rule 7).
CREATE TABLE SaleLineItem (
  saleLineItemId INTEGER PRIMARY KEY,
  transactionId  INTEGER NOT NULL,
  barcodeId      TEXT    NOT NULL,
  quantity       INTEGER NOT NULL,
  unitPrice      NUMERIC NOT NULL,
  CONSTRAINT chkSaleLineQuantity  CHECK (quantity > 0),
  CONSTRAINT chkSaleLineUnitPrice CHECK (unitPrice >= 0),
  CONSTRAINT fkSaleLineTransaction
    FOREIGN KEY (transactionId) REFERENCES SalesTransaction(transactionId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkSaleLineVariant
    FOREIGN KEY (barcodeId) REFERENCES ProductVariant(barcodeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- isPartial flags whether only some items from the original sale were returned.
-- Return quantity cap deferred to Lab 3 (rule 6).
CREATE TABLE ReturnTransaction (
  returnId              INTEGER PRIMARY KEY,
  originalTransactionId INTEGER NOT NULL,
  isPartial             INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT chkReturnIsPartial CHECK (isPartial IN (0,1)),
  CONSTRAINT fkReturnOriginalTransaction
    FOREIGN KEY (originalTransactionId) REFERENCES SalesTransaction(transactionId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE ReturnLineItem (
  returnLineItemId INTEGER PRIMARY KEY,
  returnId         INTEGER NOT NULL,
  saleLineItemId   INTEGER NOT NULL,
  quantityReturned INTEGER NOT NULL,
  CONSTRAINT chkReturnLineQuantityReturned CHECK (quantityReturned > 0),
  CONSTRAINT fkReturnLineReturn
    FOREIGN KEY (returnId) REFERENCES ReturnTransaction(returnId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkReturnLineSaleLine
    FOREIGN KEY (saleLineItemId) REFERENCES SaleLineItem(saleLineItemId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- activeLocation maps to ERD Rental_Unit.Active_Location (current store FK).
-- taxedCost maps to ERD Rental_Unit.Taxed_Cost attribute.
CREATE TABLE RentalUnit (
  rentalAssetTag  INTEGER PRIMARY KEY,
  rentalModel     TEXT    NOT NULL,
  category        TEXT    NOT NULL,
  conditionStatus TEXT    NOT NULL,
  purchaseDate    TEXT    NOT NULL,
  activeStatus    INTEGER NOT NULL DEFAULT 1,
  taxedCost       NUMERIC NOT NULL DEFAULT 0,
  activeLocation  INTEGER NOT NULL,
  CONSTRAINT chkRentalUnitCondition    CHECK (conditionStatus IN ('New','Good','Fair','Poor','Repair')),
  CONSTRAINT chkRentalUnitActiveStatus CHECK (activeStatus IN (0,1)),
  CONSTRAINT chkRentalUnitTaxedCost    CHECK (taxedCost >= 0),
  CONSTRAINT fkRentalUnitActiveLocation
    FOREIGN KEY (activeLocation) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- transactionId maps to ERD Rental_Contract.Transaction_ID (links contract to initiating sale).
-- RESTRICT: contracts are legal records and must survive store/employee deletions.
CREATE TABLE RentalContract (
  contractId    INTEGER PRIMARY KEY,
  startDate     TEXT    NOT NULL,
  expReturn     TEXT    NOT NULL,
  deposit       NUMERIC NOT NULL,
  customerId    INTEGER NOT NULL,
  storeId       INTEGER NOT NULL,
  employeeId    INTEGER NOT NULL,
  transactionId INTEGER,
  CONSTRAINT chkContractDeposit CHECK (deposit >= 0),
  CONSTRAINT chkContractDates   CHECK (expReturn >= startDate),
  CONSTRAINT fkContractCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkContractStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkContractEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkContractTransaction
    FOREIGN KEY (transactionId) REFERENCES SalesTransaction(transactionId)
      ON DELETE SET NULL ON UPDATE CASCADE
);

-- Resolves M:N Contract-RentalUnit. Overlap and min-cardinality deferred to Lab 3 (rules 3, 8).
CREATE TABLE ContractRentalUnit (
  contractId     INTEGER NOT NULL,
  rentalAssetTag INTEGER NOT NULL,
  PRIMARY KEY (contractId, rentalAssetTag),
  CONSTRAINT fkContractRentalContract
    FOREIGN KEY (contractId) REFERENCES RentalContract(contractId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkContractRentalUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- lateExtension flags extensions requested after the original expReturn date.
CREATE TABLE ContractExtension (
  extensionId   INTEGER PRIMARY KEY,
  contractId    INTEGER NOT NULL,
  extensionDate TEXT    NOT NULL,
  cost          NUMERIC NOT NULL,
  lateExtension INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT chkExtensionCost          CHECK (cost >= 0),
  CONSTRAINT chkExtensionLateExtension CHECK (lateExtension IN (0,1)),
  CONSTRAINT fkExtensionContract
    FOREIGN KEY (contractId) REFERENCES RentalContract(contractId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- chkDifferentStores prevents a transfer record with the same origin and destination.
CREATE TABLE RentalUnitTransfer (
  transferId       INTEGER PRIMARY KEY,
  rentalAssetTag   INTEGER NOT NULL,
  fromStoreId      INTEGER NOT NULL,
  toStoreId        INTEGER NOT NULL,
  transferDateTime TEXT    NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT chkDifferentStores CHECK (fromStoreId <> toStoreId),
  CONSTRAINT fkTransferUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkTransferFromStore
    FOREIGN KEY (fromStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkTransferToStore
    FOREIGN KEY (toStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- courseId stored as a code directly on Session; ERD does not model Course as its own entity.
CREATE TABLE Session (
  sessionId     INTEGER PRIMARY KEY,
  courseId      TEXT    NOT NULL,
  sessionDate   TEXT    NOT NULL,
  startTime     TEXT    NOT NULL,
  capacity      INTEGER NOT NULL,
  storeId       INTEGER NOT NULL,
  specification TEXT,
  CONSTRAINT chkSessionCapacity CHECK (capacity > 0),
  CONSTRAINT fkSessionStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- UNIQUE prevents double-enrollment of the same customer in the same session.
CREATE TABLE Enrollment (
  enrollmentId     INTEGER PRIMARY KEY,
  customerId       INTEGER NOT NULL,
  sessionId        INTEGER NOT NULL,
  enrollmentStatus TEXT    NOT NULL,
  CONSTRAINT uqEnrollmentCustomerSession UNIQUE (customerId, sessionId),
  CONSTRAINT chkEnrollmentStatus CHECK (enrollmentStatus IN ('Enrolled','Waitlisted','Cancelled','Completed')),
  CONSTRAINT fkEnrollmentCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkEnrollmentSession
    FOREIGN KEY (sessionId) REFERENCES Session(sessionId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- role maps to ERD Employee_Session.Role attribute.
-- Resolves M:N Session-Employee (instructors).
CREATE TABLE SessionInstructor (
  sessionId  INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  role       TEXT,
  PRIMARY KEY (sessionId, employeeId),
  CONSTRAINT fkInstructorSession
    FOREIGN KEY (sessionId) REFERENCES Session(sessionId)
      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fkInstructorEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE CustomerOwnedItem (
  customerItemId INTEGER PRIMARY KEY,
  customerId     INTEGER NOT NULL,
  description    TEXT    NOT NULL,
  serialNumber   TEXT,
  CONSTRAINT fkOwnedItemCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- XOR: exactly one of rentalAssetTag / customerItemId must be set.
-- Can be expressed with CHECK but deferred to Lab 3 triggers per lab instructions (rule 5).
-- SET NULL preserves ticket history if the referenced item is later removed.
CREATE TABLE ServiceTicket (
  ticketId       INTEGER PRIMARY KEY,
  status         TEXT    NOT NULL,
  priority       TEXT    NOT NULL,
  laborCost      NUMERIC NOT NULL DEFAULT 0,
  partsCost      NUMERIC NOT NULL DEFAULT 0,
  rentalAssetTag INTEGER,
  customerItemId INTEGER,
  CONSTRAINT chkServiceTicketStatus   CHECK (status IN ('Open','InProgress','Completed','Cancelled')),
  CONSTRAINT chkServiceTicketPriority CHECK (priority IN ('Low','Medium','High','Critical')),
  CONSTRAINT chkServiceTicketLabor    CHECK (laborCost >= 0),
  CONSTRAINT chkServiceTicketParts    CHECK (partsCost >= 0),
  CONSTRAINT fkServiceRentalUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fkServiceCustomerItem
    FOREIGN KEY (customerItemId) REFERENCES CustomerOwnedItem(customerItemId)
      ON DELETE SET NULL ON UPDATE CASCADE
);

-- PK = FK enforces at most one invoice per ticket.
CREATE TABLE ServiceInvoice (
  ticketId    INTEGER PRIMARY KEY,
  invoiceDate TEXT    NOT NULL,
  total       NUMERIC NOT NULL,
  CONSTRAINT chkServiceInvoiceTotal CHECK (total >= 0),
  CONSTRAINT fkInvoiceTicket
    FOREIGN KEY (ticketId) REFERENCES ServiceTicket(ticketId)
      ON DELETE CASCADE ON UPDATE CASCADE
);

-- Implements ERD Rental_Return entity (Return_ID, Rental_SKU, Condition).
-- Records the condition of a rental unit when returned from a contract.
CREATE TABLE RentalReturn (
  returnId        INTEGER PRIMARY KEY,
  contractId      INTEGER NOT NULL,
  rentalAssetTag  INTEGER NOT NULL,
  conditionStatus TEXT    NOT NULL,
  returnDateTime  TEXT    NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT chkRentalReturnCondition CHECK (conditionStatus IN ('New','Good','Fair','Poor','Damaged')),
  CONSTRAINT fkRentalReturnContract
    FOREIGN KEY (contractId) REFERENCES RentalContract(contractId)
      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fkRentalReturnUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idxEmployeeHomeStoreId         ON Employee(homeStoreId);

-- Both FK columns on join tables (composite PK only covers left-prefix).
CREATE INDEX idxEmployeeStoreStoreId        ON EmployeeStore(storeId);
CREATE INDEX idxEmployeeStoreEmployeeId     ON EmployeeStore(employeeId);
CREATE INDEX idxStoreVendorVendorId         ON StoreVendor(vendorId);
CREATE INDEX idxStoreVendorStoreId          ON StoreVendor(storeId);
CREATE INDEX idxVendorProductProductId      ON VendorProduct(productId);
CREATE INDEX idxVendorProductVendorId       ON VendorProduct(vendorId);
CREATE INDEX idxContractRentalUnitTag       ON ContractRentalUnit(rentalAssetTag);
CREATE INDEX idxSessionInstructorEmployeeId ON SessionInstructor(employeeId);

CREATE INDEX idxManagerEmployeeId           ON StoreManagerAssignment(employeeId);
CREATE INDEX idxProductSku                  ON Product(sku);
CREATE INDEX idxVariantProductId            ON ProductVariant(productId);
CREATE INDEX idxCustomerEmail               ON Customer(emailAddress);
CREATE INDEX idxAddressCustomerId           ON CustomerAddress(customerId);
CREATE INDEX idxCustomerMembershipCustomer  ON CustomerMembership(customerId);
CREATE INDEX idxCustomerMembershipTier      ON CustomerMembership(membershipId);

CREATE INDEX idxTransactionCustomerId       ON SalesTransaction(customerId);
CREATE INDEX idxTransactionStoreId          ON SalesTransaction(storeId);
CREATE INDEX idxTransactionEmployeeId       ON SalesTransaction(employeeId);
CREATE INDEX idxTransactionDateTime         ON SalesTransaction(dateTime);
CREATE INDEX idxSaleLineTransactionId       ON SaleLineItem(transactionId);
CREATE INDEX idxSaleLineBarcodeId           ON SaleLineItem(barcodeId);
CREATE INDEX idxReturnOriginalTxn           ON ReturnTransaction(originalTransactionId);
CREATE INDEX idxReturnLineReturnId          ON ReturnLineItem(returnId);
CREATE INDEX idxReturnLineSaleLineItemId    ON ReturnLineItem(saleLineItemId);

CREATE INDEX idxContractCustomerId          ON RentalContract(customerId);
CREATE INDEX idxContractStoreId             ON RentalContract(storeId);
CREATE INDEX idxContractEmployeeId          ON RentalContract(employeeId);
CREATE INDEX idxContractDates               ON RentalContract(startDate, expReturn);
CREATE INDEX idxExtensionContractId         ON ContractExtension(contractId);
CREATE INDEX idxTransferUnitTag             ON RentalUnitTransfer(rentalAssetTag);
CREATE INDEX idxTransferFromStoreId         ON RentalUnitTransfer(fromStoreId);
CREATE INDEX idxTransferToStoreId           ON RentalUnitTransfer(toStoreId);
CREATE INDEX idxTransferDateTime            ON RentalUnitTransfer(transferDateTime);

CREATE INDEX idxSessionStoreId              ON Session(storeId);
CREATE INDEX idxSessionDate                 ON Session(sessionDate);
CREATE INDEX idxEnrollmentCustomerId        ON Enrollment(customerId);
CREATE INDEX idxEnrollmentSessionId         ON Enrollment(sessionId);
CREATE INDEX idxOwnedItemCustomerId         ON CustomerOwnedItem(customerId);
CREATE INDEX idxServiceRentalUnitTag        ON ServiceTicket(rentalAssetTag);
CREATE INDEX idxServiceCustomerItemId       ON ServiceTicket(customerItemId);

-- Explicit index on ServiceInvoice FK (ticketId is also PK, but listed to satisfy
-- literal spec requirement: "index all FK columns").
CREATE INDEX idxServiceInvoiceTicketId      ON ServiceInvoice(ticketId);

-- RentalReturn FK indexes.
CREATE INDEX idxRentalReturnContractId      ON RentalReturn(contractId);
CREATE INDEX idxRentalReturnAssetTag        ON RentalReturn(rentalAssetTag);

-- RentalUnit.activeLocation FK index.
CREATE INDEX idxRentalUnitActiveLocation    ON RentalUnit(activeLocation);

-- RentalContract.transactionId FK index.
CREATE INDEX idxContractTransactionId       ON RentalContract(transactionId);

-- SalesTransaction.membershipId FK index.
CREATE INDEX idxTransactionMembershipId     ON SalesTransaction(membershipId);

-- ============================================================
-- SAMPLE DATA
-- ============================================================

INSERT INTO Storefront VALUES
  (1, '318 Broad St, Kingsport, TN',      '423-555-0184'),
  (2, '74 Commerce Dr, Gate City, VA',    '276-555-0237');

INSERT INTO Employee VALUES
  (1001, 'Manager',     '2024-03-17', 27.75, 1, 1, NULL),
  (1002, 'Sales',       '2024-09-02', 17.50, 1, 1, NULL),
  (1003, 'Repair Tech', '2023-06-28', 23.00, 1, 2, 'Bicycle and kayak repair certified'),
  (1004, 'Trainer',     '2025-04-14', 19.50, 1, 1, 'WFR certified instructor');

INSERT INTO EmployeeStore VALUES
  (1, 1001, 'Manager'),
  (2, 1002, 'Pickup Cashier');

-- 1001 manages the Kingsport location; one-active-manager rule deferred to Lab 3.
INSERT INTO StoreManagerAssignment VALUES
  (1, 1001, '2024-03-17', NULL);

INSERT INTO Vendor VALUES (501, 'Blue Ridge Outfitters Supply', 'Bristol, TN');
INSERT INTO StoreVendor VALUES (501, 1), (501, 2);

INSERT INTO Product VALUES
  (2001, 'AO-FLEECE', 'Ridgeline Fleece Jacket', 'AO', 'Apparel',   64.99, 'Taxable', 1),
  (2002, 'AO-PACK',   'Trailhead Daypack',        'AO', 'Packs',     89.99, 'Taxable', 1);

INSERT INTO ProductVariant VALUES
  ('BC-FL-S',   2001, 'Size S',  64.99, 1),
  ('BC-FL-M',   2001, 'Size M',  64.99, 1),
  ('BC-PK-ONE', 2002, '22L',     89.99, 1);

INSERT INTO VendorProduct VALUES (501, 2001, 'BRO-FLC', 31.00,  5),
                                 (501, 2002, 'BRO-PKD', 42.50, 10);

INSERT INTO Customer VALUES
  (3001, 'Dana Whitfield', '423-555-2841', 'dwhitfield@example.com', '2026-01-14', 1),
  (3002, 'Marcus Horne',   '423-555-3967', 'mhorne@example.com',     '2026-01-29', 0);

INSERT INTO CustomerAddress VALUES
  (4001, 3001, '47 Clinchfield St, Kingsport, TN', 1),
  (4002, 3002, '209 Stone Dr, Kingsport, TN',       1);

INSERT INTO Membership VALUES (6001, 'Standard', 49.99);

INSERT INTO CustomerMembership VALUES
  (7001, 3001, 6001, '2026-01-14', NULL,         1),
  (7002, 3002, 6001, '2025-07-01', '2025-12-31', 0);

INSERT INTO SalesTransaction VALUES
  (8001, '2026-02-03 11:42:00', 0.00,  64.99, 1, 3001, 1002, 6001),
  (8002, '2026-02-07 14:15:00', 5.00,  84.99, 1, 3002, 1002, NULL);

INSERT INTO SaleLineItem VALUES
  (9001, 8001, 'BC-FL-S',   1, 64.99),
  (9002, 8002, 'BC-FL-M',   1, 64.99),
  (9003, 8002, 'BC-PK-ONE', 1, 89.99);

-- Partial return: Dana returned the fleece from transaction 8001.
INSERT INTO ReturnTransaction VALUES (9101, 8001, 1);
INSERT INTO ReturnLineItem VALUES (9201, 9101, 9001, 1);

INSERT INTO RentalUnit VALUES
  (10001, 'Kelty Tent 4P',    'Camping', 'Good', '2024-08-12', 1, 25.00, 1),
  (10002, 'Dagger Kayak 10R', 'Water',   'Fair', '2022-11-03', 1, 40.00, 1);

INSERT INTO RentalUnitTransfer VALUES (11001, 10002, 2, 1, '2026-01-28 09:15:00');

INSERT INTO RentalContract VALUES
  (12001, '2026-02-14', '2026-02-17', 45.00, 3001, 1, 1002, NULL);

INSERT INTO ContractRentalUnit VALUES (12001, 10001), (12001, 10002);
INSERT INTO ContractExtension VALUES (13001, 12001, '2026-02-17', 12.00, 0);

INSERT INTO Session VALUES (14001, 'WFR-101', '2026-02-25', '09:00:00', 15, 1, 'Wilderness First Response Basics');
INSERT INTO Enrollment VALUES
  (15001, 3001, 14001, 'Enrolled'),
  (15002, 3002, 14001, 'Enrolled');

INSERT INTO SessionInstructor VALUES (14001, 1004, 'Lead Instructor');

INSERT INTO CustomerOwnedItem VALUES (16001, 3001, 'Osprey hip belt buckle replacement', 'OSP-4492');

INSERT INTO ServiceTicket VALUES
  (17001, 'Open',      'High', 40.00, 15.00, 10002, NULL),
  (17002, 'Completed', 'Low',  20.00,  8.00, NULL,  16001);

INSERT INTO ServiceInvoice VALUES (17002, '2026-02-11', 28.00);

-- Rental return: kayak returned from contract 12001 in Fair condition.
INSERT INTO RentalReturn VALUES (18001, 12001, 10002, 'Fair', '2026-02-17 10:30:00');

-- ============================================================
-- CONSTRAINT VIOLATION TESTS (commented out)
-- ============================================================

-- TEST 1: FK violation — homeStoreId 999 does not exist.
-- INSERT INTO Employee VALUES (1999, 'Sales', '2026-02-25', 18.00, 1, 999);

-- TEST 2: UNIQUE violation — sku 'AO-TSHIRT' already exists.
-- INSERT INTO Product VALUES (2999, 'AO-TSHIRT', 'Dupe', 'AO', 'Apparel', 10.00, 'Taxable', 1);

-- TEST 3: CHECK violation — quantity must be > 0.
-- INSERT INTO SaleLineItem VALUES (9991, 8001, 'BC-AO-TS-M', 0, 19.99);

-- TEST 4: CHECK violation — cost cannot be negative.
-- INSERT INTO Membership VALUES (6999, 'Bad', -5.00);

-- TEST 5: CHECK violation — invalid status value.
-- INSERT INTO ServiceTicket VALUES (17999, 'PENDING', 'High', 10.00, 0.00, 10001, NULL);

-- TEST 6: CHECK violation — invalid taxStatus value.
-- INSERT INTO Product VALUES (3000, 'AO-MISC', 'Misc', 'AO', 'Misc', 1.00, 'Sometimes', 1);

-- TEST 7: CHECK violation — fromStoreId and toStoreId cannot be the same.
-- INSERT INTO RentalUnitTransfer VALUES (11999, 10001, 1, 1, '2026-02-20 09:00:00');
