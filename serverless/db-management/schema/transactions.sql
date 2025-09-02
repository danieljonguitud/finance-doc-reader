-- atlas:import users.sql
-- atlas:import accounts.sql
-- atlas:import functions/update_updated_at.sql

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    
    -- Transaction details
    transaction_date DATE NOT NULL,
    description TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    category VARCHAR(100) NOT NULL,
    
    -- Internal transfer handling
    internal_transfer_id BIGINT REFERENCES transactions(id),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_amount CHECK (amount != 0),
    CONSTRAINT valid_internal_transfer CHECK (
        internal_transfer_id IS NULL OR 
        internal_transfer_id != id
    )
);

-- Indexes 
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_transactions_amount ON transactions(amount);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transactions_internal_transfer ON transactions(internal_transfer_id);

-- Composite indexes for account-based queries
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_user_category ON transactions(user_id, category);
CREATE INDEX idx_transactions_user_type_date ON transactions(user_id, transaction_type, transaction_date DESC);
CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date DESC);
CREATE INDEX idx_transactions_account_type ON transactions(account_id, transaction_type);
CREATE INDEX idx_transactions_user_account ON transactions(user_id, account_id);

-- Index for excluding internal transfers in summary queries
CREATE INDEX idx_transactions_non_transfer ON transactions(user_id, transaction_type, transaction_date DESC) 
    WHERE internal_transfer_id IS NULL;

-- Triggers
CREATE TRIGGER trigger_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
