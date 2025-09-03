-- atlas:import users.sql
-- atlas:import functions/update_updated_at.sql

CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Account identification
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('checking', 'credit_card')),
    institution VARCHAR(100) NOT NULL,
    
    -- Secure account number storage
    account_number_hash VARCHAR(64) NOT NULL, -- SHA-256 hash for matching/deduplication
    display_digits VARCHAR(10),               -- Last 4 digits for display: "****1234"
    
    -- Account properties
    is_liability BOOLEAN DEFAULT FALSE,       -- true for credit cards, loans
    account_balance DECIMAL(15,2) NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT unique_user_account_hash UNIQUE (user_id, account_number_hash),
    CONSTRAINT valid_display_digits CHECK (display_digits ~ '^\*{4}\d{1,6}$' OR display_digits IS NULL)
);

-- Indexes for performance
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_user_type ON accounts(user_id, account_type);
CREATE INDEX idx_accounts_hash ON accounts(account_number_hash);
CREATE INDEX idx_accounts_created_at ON accounts(created_at);

-- Composite indexes for common queries
CREATE INDEX idx_accounts_user_liability ON accounts(user_id, is_liability);
CREATE INDEX idx_accounts_user_institution ON accounts(user_id, institution);

-- Triggers
CREATE TRIGGER trigger_accounts_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
