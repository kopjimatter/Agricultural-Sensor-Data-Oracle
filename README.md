# 🌾 Agricultural Sensor Data Oracle

A Clarity smart contract that enables IoT agricultural sensors to feed real-time data to the Stacks blockchain through authorized oracles.

## 🚀 Features

- 📡 **Sensor Registration**: Register agricultural IoT sensors with location and type information
- 🔐 **Oracle Management**: Register and authorize trusted oracles to submit sensor data
- 📊 **Real-time Data**: Submit and retrieve temperature, humidity, soil moisture, pH levels, light intensity, and rainfall data
- 💰 **Subscription Model**: Pay-per-access model for sensor data consumption
- 🛡️ **Access Control**: Sensor owners control which oracles can submit data
- 📈 **Oracle Reputation**: Track oracle performance and reliability

## 🏗️ Contract Structure

### Core Entities

- **Sensors**: IoT devices registered by owners with location and type metadata
- **Oracles**: Trusted entities authorized to submit sensor data to the blockchain
- **Sensor Data**: Time-stamped agricultural measurements from field sensors
- **Subscriptions**: Paid access to specific sensor data streams

## 📋 Usage Instructions

### For Sensor Owners

#### 1. Register a Sensor
```clarity
(contract-call? .agricultural-oracle register-sensor "Farm Field A1" "soil-monitor")
```

#### 2. Authorize an Oracle
```clarity
(contract-call? .agricultural-oracle authorize-oracle u1 u1)
```

#### 3. Deactivate a Sensor
```clarity
(contract-call? .agricultural-oracle deactivate-sensor u1)
```

### For Oracles

#### 1. Register as Oracle
```clarity
(contract-call? .agricultural-oracle register-oracle "WeatherTech Oracle")
```

#### 2. Submit Sensor Data
```clarity
(contract-call? .agricultural-oracle submit-sensor-data 
  u1    ;; oracle-id
  u1    ;; sensor-id
  25    ;; temperature (°C)
  u65   ;; humidity (%)
  u45   ;; soil-moisture (%)
  u650  ;; ph-level (pH * 100)
  u850  ;; light-intensity (lux)
  u12   ;; rainfall (mm)
)
```

### For Data Consumers

#### 1. Subscribe to Sensor
```clarity
(contract-call? .agricultural-oracle subscribe-to-sensor u1)
```

#### 2. Get Latest Data
```clarity
(contract-call? .agricultural-oracle get-latest-sensor-data u1)
```

#### 3. Get Historical Data
```clarity
(contract-call? .agricultural-oracle get-sensor-data-at-time u1 u12345)
```

## 🔍 Read-Only Functions

- `get-sensor-info`: Retrieve sensor metadata
- `get-latest-sensor-data`: Get most recent sensor readings
- `get-sensor-data-at-time`: Get historical sensor data
- `get-oracle-info`: Retrieve oracle information and reputation
- `is-oracle-authorized`: Check oracle permissions for a sensor
- `get-subscription-status`: Check subscription status
- `get-oracle-fee`: Get current subscription fee

## 💡 Data Format

### Sensor Data Structure
- **Temperature**: Integer in Celsius (can be negative)
- **Humidity**: Percentage (0-100)
- **Soil Moisture**: Percentage (0-100)
- **pH Level**: pH value × 100 (0-1400, representing 0.00-14.00 pH)
- **Light Intensity**: Lux value
- **Rainfall**: Millimeters

## 🛠️ Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 🔒 Security Features

- Owner-only sensor management
- Oracle authorization system
- Data validation for sensor readings
- Subscription-based access control
- Reputation tracking for oracles

## 📊 Use Cases

- 🌱 **Precision Agriculture**: Monitor crop conditions in real-time
- 💧 **Irrigation Management**: Optimize water usage based on soil moisture
- 🌡️ **Climate Monitoring**: Track environmental conditions for research
- 📈 **Yield Prediction**: Use historical data for crop yield forecasting
- 🚨 **Alert Systems**: Trigger notifications for critical conditions

## 🤝 Contributing

This is an MVP implementation. Future enhancements could include:
- Data aggregation functions
- Advanced oracle consensus mechanisms
- Integration with DeFi protocols for automated payments
- Machine learning predictions based on historical data
```

**Git Commit Message:**
```
feat: implement agricultural sensor data oracle MVP with IoT integration
```

**GitHub Pull Request Title:**
```
🌾 Add Agricultural Sensor Data Oracle MVP
```

**GitHub Pull Request Description:**
```
## Summary
Implements a complete Agricultural Sensor Data Oracle smart contract that enables IoT devices to feed real-time agricultural data to the Stacks blockchain.

## What's Added
- **Sensor Management**: Registration, authorization, and deactivation of agricultural sensors
- **Oracle System**: Trusted entities can submit verified sensor data with reputation tracking  
- **Real-time Data Feed**: Support for temperature, humidity, soil moisture, pH, light, and rainfall data
- **Subscription Model**: Pay-per-access system for data consumers
- **Access Control**: Comprehensive permission system for sensor owners and oracles
- **Data Validation**: Input validation for all sensor readings to ensure data integrity

## Key Features
- 150+ lines of production-ready Clarity code
- Complete CRUD operations for sensors and oracles
- Time-stamped data storage with historical access
- Oracle reputation and performance tracking
- Subscription-based monetization model

## Files Changed
- `contracts/agricultural-oracle.clar` - Main smart contract implementation
- `README.md` - Comprehensive documentation with usage examples

Ready for integration with IoT devices and agricultural monitoring systems.
