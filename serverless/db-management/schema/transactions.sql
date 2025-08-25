-- atlas:import users.sql
-- atlas:import functions/update_updated_at.sql

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id SERIAL NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Transaction details
    transaction_date DATE NOT NULL,
    description TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    category VARCHAR(100) NOT NULL,
    
    -- Bank/Account information
    bank_name VARCHAR(100),
    account_holder VARCHAR(255),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_amount CHECK (amount != 0)
);

-- Indexes 
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_transactions_amount ON transactions(amount);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);

-- Composite indexes 
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_user_category ON transactions(user_id, category);
CREATE INDEX idx_transactions_user_type_date ON transactions(user_id, transaction_type, transaction_date DESC);

-- Triggers
CREATE TRIGGER trigger_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
