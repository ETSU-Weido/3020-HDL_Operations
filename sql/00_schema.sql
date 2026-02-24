PRAGMA foreign_keys = ON;

-- ----------------------------
-- DROP TABLES (dependency order)
-- ----------------------------
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
DROP TABLE IF EXISTS VendorProduct;
DROP TABLE IF EXISTS ProductVariant;
DROP TABLE IF EXISTS Product;
DROP TABLE IF EXISTS Vendor;
DROP TABLE IF EXISTS StoreManagerAssignment;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS RentalUnit;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Storefront;

-- ----------------------------
-- CORE TABLES
-- ----------------------------

CREATE TABLE Storefront (
  storeId INTEGER PRIMARY KEY,
  physicalAddress TEXT NOT NULL,
  phoneNumber TEXT NOT NULL
);

CREATE TABLE Employee (
  employeeId INTEGER PRIMARY KEY,
  role TEXT NOT NULL,
  hireDate TEXT NOT NULL, -- store as ISO date YYYY-MM-DD
  hourlyRate NUMERIC NOT NULL CHECK (hourlyRate >= 0),
  activeStatus INTEGER NOT NULL DEFAULT 1 CHECK (activeStatus IN (0,1)),
  homeStoreId INTEGER NOT NULL,
  CONSTRAINT fkEmployeeHomeStore
    FOREIGN KEY (homeStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE StoreManagerAssignment (
  storeId INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  startDate TEXT NOT NULL,
  endDate TEXT,
  CONSTRAINT chkManagerDates CHECK (endDate IS NULL OR endDate >= startDate),
  PRIMARY KEY (storeId, employeeId, startDate),
  CONSTRAINT fkManagerStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkManagerEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE Vendor (
  vendorId INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  physicalLocation TEXT
);

CREATE TABLE Product (
  productId INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT NOT NULL,
  taxStatus TEXT NOT NULL,
  activeStatus INTEGER NOT NULL DEFAULT 1 CHECK (activeStatus IN (0,1))
);

CREATE TABLE ProductVariant (
  barcodeId TEXT PRIMARY KEY,
  productId INTEGER NOT NULL,
  variantDescriptor TEXT,
  unitPrice NUMERIC NOT NULL CHECK (unitPrice >= 0),
  activeStatus INTEGER NOT NULL DEFAULT 1 CHECK (activeStatus IN (0,1)),
  CONSTRAINT fkVariantProduct
    FOREIGN KEY (productId) REFERENCES Product(productId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE VendorProduct (
  vendorId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  vendorSku TEXT,
  unitCost NUMERIC NOT NULL CHECK (unitCost >= 0),
  leadTimeDays INTEGER CHECK (leadTimeDays >= 0),
  PRIMARY KEY (vendorId, productId),
  CONSTRAINT fkVendorProductVendor
    FOREIGN KEY (vendorId) REFERENCES Vendor(vendorId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkVendorProductProduct
    FOREIGN KEY (productId) REFERENCES Product(productId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE Customer (
  customerId INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  phoneNumber TEXT,
  emailAddress TEXT,
  creationDate TEXT NOT NULL DEFAULT (date('now'))
);

CREATE TABLE CustomerAddress (
  addressId INTEGER PRIMARY KEY,
  customerId INTEGER NOT NULL,
  addressString TEXT NOT NULL,
  isPreferred INTEGER NOT NULL DEFAULT 0 CHECK (isPreferred IN (0,1)),
  CONSTRAINT fkAddressCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE Membership (
  membershipId INTEGER PRIMARY KEY,
  cost NUMERIC NOT NULL CHECK (cost >= 0)
);

CREATE TABLE CustomerMembership (
  customerMembershipId INTEGER PRIMARY KEY,
  customerId INTEGER NOT NULL,
  membershipId INTEGER NOT NULL,
  startDate TEXT NOT NULL,
  endDate TEXT,
  isActive INTEGER NOT NULL DEFAULT 1 CHECK (isActive IN (0,1)),
  CONSTRAINT chkMembershipDates CHECK (endDate IS NULL OR endDate >= startDate),
  CONSTRAINT chkActiveMembershipEndDate CHECK (isActive = 0 OR endDate IS NULL),
  CONSTRAINT fkCustomerMembershipCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkCustomerMembershipMembership
    FOREIGN KEY (membershipId) REFERENCES Membership(membershipId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

-- ----------------------------
-- SALES / RETURNS
-- ----------------------------

CREATE TABLE SalesTransaction (
  transactionId INTEGER PRIMARY KEY,
  dateTime TEXT NOT NULL DEFAULT (datetime('now')),
  discount NUMERIC NOT NULL DEFAULT 0 CHECK (discount >= 0),
  taxedTotal NUMERIC NOT NULL CHECK (taxedTotal >= 0),
  storeId INTEGER NOT NULL,
  customerId INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  CONSTRAINT fkTransactionStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkTransactionCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkTransactionEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE SaleLineItem (
  saleLineItemId INTEGER PRIMARY KEY,
  transactionId INTEGER NOT NULL,
  barcodeId TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unitPrice NUMERIC NOT NULL CHECK (unitPrice >= 0),
  CONSTRAINT fkSaleLineTransaction
    FOREIGN KEY (transactionId) REFERENCES SalesTransaction(transactionId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkSaleLineVariant
    FOREIGN KEY (barcodeId) REFERENCES ProductVariant(barcodeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE ReturnTransaction (
  returnId INTEGER PRIMARY KEY,
  originalTransactionId INTEGER NOT NULL,
  CONSTRAINT fkReturnOriginalTransaction
    FOREIGN KEY (originalTransactionId) REFERENCES SalesTransaction(transactionId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE ReturnLineItem (
  returnLineItemId INTEGER PRIMARY KEY,
  returnId INTEGER NOT NULL,
  saleLineItemId INTEGER NOT NULL,
  quantityReturned INTEGER NOT NULL CHECK (quantityReturned > 0),
  CONSTRAINT fkReturnLineReturn
    FOREIGN KEY (returnId) REFERENCES ReturnTransaction(returnId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkReturnLineSaleLine
    FOREIGN KEY (saleLineItemId) REFERENCES SaleLineItem(saleLineItemId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

-- ----------------------------
-- RENTALS
-- ----------------------------

CREATE TABLE RentalUnit (
  rentalAssetTag INTEGER PRIMARY KEY,
  rentalModel TEXT NOT NULL,
  category TEXT NOT NULL,
  conditionStatus TEXT NOT NULL,
  purchaseDate TEXT NOT NULL,
  activeStatus INTEGER NOT NULL DEFAULT 1 CHECK (activeStatus IN (0,1))
);

CREATE TABLE RentalContract (
  contractId INTEGER PRIMARY KEY,
  startDate TEXT NOT NULL,
  expReturn TEXT NOT NULL,
  deposit NUMERIC NOT NULL CHECK (deposit >= 0),
  customerId INTEGER NOT NULL,
  storeId INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  CONSTRAINT chkContractDates CHECK (expReturn >= startDate),
  CONSTRAINT fkContractCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkContractStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkContractEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE ContractRentalUnit (
  contractId INTEGER NOT NULL,
  rentalAssetTag INTEGER NOT NULL,
  PRIMARY KEY (contractId, rentalAssetTag),
  CONSTRAINT fkContractRentalContract
    FOREIGN KEY (contractId) REFERENCES RentalContract(contractId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkContractRentalUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE ContractExtension (
  extensionId INTEGER PRIMARY KEY,
  contractId INTEGER NOT NULL,
  extensionDate TEXT NOT NULL,
  cost NUMERIC NOT NULL CHECK (cost >= 0),
  lateExtension INTEGER NOT NULL DEFAULT 0 CHECK (lateExtension IN (0,1)),
  CONSTRAINT fkExtensionContract
    FOREIGN KEY (contractId) REFERENCES RentalContract(contractId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE RentalUnitTransfer (
  transferId INTEGER PRIMARY KEY,
  rentalAssetTag INTEGER NOT NULL,
  fromStoreId INTEGER NOT NULL,
  toStoreId INTEGER NOT NULL,
  transferDateTime TEXT NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT chkDifferentStores CHECK (fromStoreId <> toStoreId),
  CONSTRAINT fkTransferUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkTransferFromStore
    FOREIGN KEY (fromStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE,
  CONSTRAINT fkTransferToStore
    FOREIGN KEY (toStoreId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

-- ----------------------------
-- SESSIONS / ENROLLMENTS
-- ----------------------------

CREATE TABLE Session (
  sessionId INTEGER PRIMARY KEY,
  courseId TEXT NOT NULL,
  sessionDate TEXT NOT NULL,
  startTime TEXT NOT NULL, -- HH:MM:SS
  capacity INTEGER NOT NULL CHECK (capacity > 0),
  storeId INTEGER NOT NULL,
  specification TEXT,
  CONSTRAINT fkSessionStore
    FOREIGN KEY (storeId) REFERENCES Storefront(storeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

CREATE TABLE Enrollment (
  enrollmentId INTEGER PRIMARY KEY,
  customerId INTEGER NOT NULL,
  sessionId INTEGER NOT NULL,
  enrollmentStatus TEXT NOT NULL,
  CONSTRAINT fkEnrollmentCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkEnrollmentSession
    FOREIGN KEY (sessionId) REFERENCES Session(sessionId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT uqEnrollmentCustomerSession UNIQUE (customerId, sessionId)
);

CREATE TABLE SessionInstructor (
  sessionId INTEGER NOT NULL,
  employeeId INTEGER NOT NULL,
  PRIMARY KEY (sessionId, employeeId),
  CONSTRAINT fkInstructorSession
    FOREIGN KEY (sessionId) REFERENCES Session(sessionId)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
  CONSTRAINT fkInstructorEmployee
    FOREIGN KEY (employeeId) REFERENCES Employee(employeeId)
      ON DELETE RESTRICT
      ON UPDATE CASCADE
);

-- ----------------------------
-- SERVICE
-- ----------------------------

CREATE TABLE CustomerOwnedItem (
  customerItemId INTEGER PRIMARY KEY,
  customerId INTEGER NOT NULL,
  description TEXT NOT NULL,
  serialNumber TEXT,
  CONSTRAINT fkOwnedItemCustomer
    FOREIGN KEY (customerId) REFERENCES Customer(customerId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE ServiceTicket (
  ticketId INTEGER PRIMARY KEY,
  status TEXT NOT NULL,
  priority TEXT NOT NULL,
  laborCost NUMERIC NOT NULL DEFAULT 0 CHECK (laborCost >= 0),
  partsCost NUMERIC NOT NULL DEFAULT 0 CHECK (partsCost >= 0),
  rentalAssetTag INTEGER,
  customerItemId INTEGER,
  CONSTRAINT chkServiceTargetExclusivity CHECK (
    (rentalAssetTag IS NOT NULL AND customerItemId IS NULL) OR
    (rentalAssetTag IS NULL AND customerItemId IS NOT NULL)
  ),
  CONSTRAINT fkServiceRentalUnit
    FOREIGN KEY (rentalAssetTag) REFERENCES RentalUnit(rentalAssetTag)
      ON DELETE SET NULL
      ON UPDATE CASCADE,
  CONSTRAINT fkServiceCustomerItem
    FOREIGN KEY (customerItemId) REFERENCES CustomerOwnedItem(customerItemId)
      ON DELETE SET NULL
      ON UPDATE CASCADE
);

CREATE TABLE ServiceInvoice (
  ticketId INTEGER PRIMARY KEY,
  invoiceDate TEXT NOT NULL,
  total NUMERIC NOT NULL CHECK (total >= 0),
  CONSTRAINT fkInvoiceTicket
    FOREIGN KEY (ticketId) REFERENCES ServiceTicket(ticketId)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

-- ----------------------------
-- INDEXES (FK columns + common queries)
-- ----------------------------

-- Employee
CREATE INDEX idxEmployeeHomeStoreId ON Employee(homeStoreId);

-- StoreManagerAssignment
CREATE INDEX idxManagerEmployeeId ON StoreManagerAssignment(employeeId);

-- ProductVariant / VendorProduct
CREATE INDEX idxVariantProductId ON ProductVariant(productId);
CREATE INDEX idxVendorProductProductId ON VendorProduct(productId);

-- CustomerAddress / CustomerMembership
CREATE INDEX idxAddressCustomerId ON CustomerAddress(customerId);
CREATE INDEX idxCustomerMembershipCustomerId ON CustomerMembership(customerId);
CREATE INDEX idxCustomerMembershipMembershipId ON CustomerMembership(membershipId);

-- SalesTransaction
CREATE INDEX idxTransactionCustomerId ON SalesTransaction(customerId);
CREATE INDEX idxTransactionStoreId ON SalesTransaction(storeId);
CREATE INDEX idxTransactionEmployeeId ON SalesTransaction(employeeId);
CREATE INDEX idxTransactionDateTime ON SalesTransaction(dateTime);

-- SaleLineItem / Returns
CREATE INDEX idxSaleLineTransactionId ON SaleLineItem(transactionId);
CREATE INDEX idxSaleLineBarcodeId ON SaleLineItem(barcodeId);
CREATE INDEX idxReturnOriginalTransactionId ON ReturnTransaction(originalTransactionId);
CREATE INDEX idxReturnLineReturnId ON ReturnLineItem(returnId);
CREATE INDEX idxReturnLineSaleLineItemId ON ReturnLineItem(saleLineItemId);

-- RentalContract / related
CREATE INDEX idxContractCustomerId ON RentalContract(customerId);
CREATE INDEX idxContractStoreId ON RentalContract(storeId);
CREATE INDEX idxContractEmployeeId ON RentalContract(employeeId);
CREATE INDEX idxContractDates ON RentalContract(startDate, expReturn);
CREATE INDEX idxContractRentalUnitTag ON ContractRentalUnit(rentalAssetTag);
CREATE INDEX idxExtensionContractId ON ContractExtension(contractId);

-- RentalUnitTransfer
CREATE INDEX idxTransferUnitTag ON RentalUnitTransfer(rentalAssetTag);
CREATE INDEX idxTransferDateTime ON RentalUnitTransfer(transferDateTime);
CREATE INDEX idxTransferFromStoreId ON RentalUnitTransfer(fromStoreId);
CREATE INDEX idxTransferToStoreId ON RentalUnitTransfer(toStoreId);

-- Session / Enrollment / Instructor
CREATE INDEX idxSessionStoreId ON Session(storeId);
CREATE INDEX idxSessionDate ON Session(sessionDate);
CREATE INDEX idxEnrollmentCustomerId ON Enrollment(customerId);
CREATE INDEX idxEnrollmentSessionId ON Enrollment(sessionId);

-- Service
CREATE INDEX idxOwnedItemCustomerId ON CustomerOwnedItem(customerId);
CREATE INDEX idxServiceRentalUnitTag ON ServiceTicket(rentalAssetTag);
CREATE INDEX idxServiceCustomerItemId ON ServiceTicket(customerItemId);
