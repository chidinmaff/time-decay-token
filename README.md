# Time Decay Token System

A comprehensive smart contract system for creating and managing time-decay tokens on the Stacks blockchain. These tokens automatically lose value over time according to configurable decay parameters, enabling unique economic mechanisms and use cases.

## Features

### Core Token Contract (`time-decay-token.clar`)

- **SIP-010 Compliant**: Fully implements the standard fungible token interface
- **Time-Based Decay**: Tokens automatically lose value over time based on configurable parameters
- **Flexible Decay Models**: Customizable decay rate, start block, and minimum balance floor
- **Real-Time Balance Calculation**: Balances are calculated dynamically based on elapsed time
- **Decay Control**: Admin functions to enable/disable decay and modify parameters
- **Balance Snapshots**: Efficient tracking of balance states to minimize gas costs

### Factory Contract (`time-decay-factory.clar`)

- **Token Creation**: Deploy new time-decay tokens with custom parameters
- **Registry System**: Track all created tokens and their metadata
- **Creator Management**: Associate tokens with their creators
- **Event Logging**: Comprehensive activity tracking for all tokens
- **Statistical Analysis**: Built-in analytics for token usage and activity
- **Fee Management**: Configurable fees for token creation

## Use Cases

1. **Promotional Tokens**: Marketing campaigns with expiring value
2. **Reward Systems**: Time-sensitive rewards that encourage quick usage
3. **Economic Experiments**: Testing novel economic models with decay
4. **Gaming Tokens**: In-game currencies with natural deflation
5. **Subscription Models**: Time-based access tokens
6. **Carbon Credits**: Environmental tokens with degrading value

## Technical Architecture

### Decay Calculation Algorithm

The decay system uses an exponential decay model:

```
decayed_balance = original_balance × (1 - decay_rate)^blocks_elapsed
```

Where:
- `decay_rate`: Rate of decay per block (in basis points, 1-10000)
- `blocks_elapsed`: Number of blocks since last update or decay start
- `minimum_balance`: Floor value to prevent complete decay to zero

### Key Components

1. **Balance Snapshots**: Store last known balance and update block for each holder
2. **Dynamic Calculation**: Real-time balance computation without requiring updates
3. **Decay Parameters**: Configurable start block, rate, and minimum thresholds
4. **Administrative Controls**: Owner functions for parameter management

## Installation & Deployment

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for deployment
- Node.js (for testing scripts)

### Deployment Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd time-decay-token
   ```

2. **Install Dependencies**
   ```bash
   npm install
   clarinet integrate
   ```

3. **Run Tests**
   ```bash
   clarinet test
   ```

4. **Deploy to Testnet**
   ```bash
   clarinet deploy --testnet
   ```

5. **Deploy to Mainnet**
   ```bash
   clarinet deploy --mainnet
   ```

## Usage Examples

### Creating a New Decay Token

```clarity
;; Create a token that decays 1% per block starting at block 1000
(contract-call? .time-decay-factory create-decay-token 
  "Promo Token" 
  "PROMO" 
  u100    ;; 1% decay per block (100 basis points)
  u1000)  ;; Start decay at block 1000
```

### Minting Tokens

```clarity
;; Mint 1000 tokens to a user
(contract-call? .time-decay-token mint u1000000000 'SP1234...)
```

### Checking Current Balance

```clarity
;; Get current balance (includes decay calculation)
(contract-call? .time-decay-token get-balance 'SP1234...)
```

### Predicting Future Balance

```clarity
;; Calculate what balance will be at a future block
(contract-call? .time-decay-token calculate-future-balance 'SP1234... u2000)
```

## Security Considerations

### Access Control

- **Contract Owner**: Has exclusive rights to mint, burn, and modify parameters
- **Token Holders**: Can transfer their tokens and check balances
- **Factory Owner**: Controls factory settings and fee collection

### Potential Risks

1. **Calculation Complexity**: Exponential calculations may hit computation limits with large numbers
2. **MEV Opportunities**: Decay timing might create arbitrage opportunities
3. **Gas Costs**: Dynamic balance calculations increase transaction costs
4. **Parameter Changes**: Admin control over decay parameters requires trust

### Mitigation Strategies

- Comprehensive testing with edge cases
- Parameter validation and bounds checking
- Emergency pause functionality
- Gradual parameter changes with time delays

## API Reference

### Core Token Functions

#### Read-Only Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get-balance` | `principal` | `uint` | Current balance including decay |
| `get-name` | - | `string-ascii 32` | Token name |
| `get-symbol` | - | `string-ascii 10` | Token symbol |
| `get-decimals` | - | `uint` | Number of decimals |
| `get-total-supply` | - | `uint` | Total token supply |
| `get-decay-info` | - | `tuple` | Current decay parameters |
| `calculate-future-balance` | `principal, uint` | `uint` | Predicted balance at future block |

#### Public Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `transfer` | `uint, principal, principal, memo` | `response` | Transfer tokens |
| `mint` | `uint, principal` | `response` | Mint new tokens (owner only) |
| `burn` | `uint, principal` | `response` | Burn tokens (owner only) |
| `set-decay-rate` | `uint` | `response` | Update decay rate (owner only) |
| `toggle-decay` | - | `response` | Enable/disable decay (owner only) |
| `update-balance` | `principal` | `response` | Force balance update |

### Factory Functions

#### Read-Only Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get-token-info` | `uint` | `tuple` | Token metadata |
| `get-tokens-by-creator` | `principal` | `list` | Creator's token list |
| `get-token-stats` | `uint` | `tuple` | Token usage statistics |
| `get-factory-info` | - | `tuple` | Factory configuration |

#### Public Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `create-decay-token` | `name, symbol, rate, start-block` | `uint` | Create new token |
| `register-token-activity` | `uint, string, uint, principal` | `response` | Log token activity |
| `set-factory-fee` | `uint` | `response` | Update creation fee |

## Testing

### Test Coverage

- Basic token functionality (mint, burn, transfer)
- Decay calculation accuracy
- Balance snapshot management
- Administrative controls
- Error handling and edge cases
- Factory token creation
- Event logging and statistics

### Running Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/time-decay-token_test.ts

# Run with coverage
clarinet test --coverage
```

## Gas Optimization

### Efficient Operations

1. **Lazy Updates**: Balances calculated on-demand rather than continuous updates
2. **Minimal Storage**: Snapshots store only essential data
3. **Batch Operations**: Factory supports bulk token queries
4. **Optimized Math**: Efficient exponential decay calculations

### Cost Analysis

| Operation | Estimated Cost | Notes |
|-----------|----------------|-------|
| Token Creation | ~50,000 gas | One-time factory cost |
| Basic Transfer | ~15,000 gas | Plus decay calculation |
| Balance Query | ~5,000 gas | Read-only operation |
| Mint/Burn | ~20,000 gas | Admin operations |

## Upgrade Path

The contracts are designed with upgradability considerations:

1. **Parameter Updates**: Most settings can be changed by admin
2. **Feature Flags**: Decay can be disabled if needed
3. **Emergency Controls**: Pause functionality for critical issues
4. **Migration Support**: Token balances can be snapshot for migrations

## Contributing

### Development Workflow

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open Pull Request

### Code Standards

- Follow Clarity best practices
- Include comprehensive tests
- Document all public functions
- Use clear variable naming
- Add inline comments for complex logic


## Support

### Common Issues

**Q: Why is my balance decreasing over time?**
A: This is the expected behavior for time-decay tokens. Check the decay parameters with `get-decay-info`.

**Q: Can I stop the decay process?**
A: Only the contract owner can disable decay using the `toggle-decay` function.

**Q: What happens when tokens reach the minimum balance?**
A: Tokens stop decaying once they reach the configured minimum balance floor.

## Roadmap

### Phase 1
- Core token implementation
- Factory contract
- Basic testing suite

### Phase 2
- Advanced decay models (linear, logarithmic)
- Multi-token batch operations
- Integration with DeFi protocols

### Phase 3
- Cross-chain compatibility
- Advanced analytics dashboard
- Automated parameter optimization

### Phase 4
- Mobile SDK
- Governance token integration
- Enterprise features

---

**Disclaimer**: Time-decay tokens are experimental. Use with caution in production environments and conduct thorough testing before deployment.