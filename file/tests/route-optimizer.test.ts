import { 
    Chain,
    Account,
    types,
    assertEquals,
    test
} from "../deps.ts";

import { 
    deployContract,
    createRoute,
    updateRouteMetrics,
    getRoute,
    getRouteMetrics
} from "./helpers.ts";

// Test accounts
const deployer = new Account("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM");
const user1 = new Account("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG");
const user2 = new Account("ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC");

// Test data
const validStops = [
    user1.address,
    user2.address
];

const vehicleType = "truck";

Clarinet.test({
    name: "Ensure contract owner can create valid routes",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        // Deploy contract
        const deployer = accounts.get("deployer")!;
        const block = chain.mineBlock([
            createRoute(deployer, validStops, 1000, 120, vehicleType)
        ]);
        
        // Assert successful creation
        assertEquals(block.receipts[0].result.expectOk(), "u0");
        
        // Verify route data
        const route = getRoute(chain, "u0");
        assertEquals(route.stops.length, 2);
        assertEquals(route.vehicle_type, vehicleType);
    }
});

Clarinet.test({
    name: "Ensure non-owners cannot create routes",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user = accounts.get("wallet_1")!;
        const block = chain.mineBlock([
            createRoute(user, validStops, 1000, 120, vehicleType)
        ]);
        
        // Assert unauthorized error
        block.receipts[0].result.expectErr(401);
    }
});

Clarinet.test({
    name: "Ensure route metrics can be updated correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        // Create route first
        let block = chain.mineBlock([
            createRoute(deployer, validStops, 1000, 120, vehicleType)
        ]);
        
        // Update metrics
        block = chain.mineBlock([
            updateRouteMetrics(deployer, "u0", 50, 110, 2000)
        ]);
        
        // Verify metrics
        const metrics = getRouteMetrics(chain, "u0");
        assertEquals(metrics.fuel_consumed, 50);
        assertEquals(metrics.time_taken, 110);
        assertEquals(metrics.waste_collected, 2000);
    }
});

Clarinet.test({
    name: "Ensure route creation fails with invalid parameters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        // Test empty stops list
        let block = chain.mineBlock([
            createRoute(deployer, [], 1000, 120, vehicleType)
        ]);
        block.receipts[0].result.expectErr(402);
        
        // Test too many stops
        const tooManyStops = Array(21).fill(user1.address);
        block = chain.mineBlock([
            createRoute(deployer, tooManyStops, 1000, 120, vehicleType)
        ]);
        block.receipts[0].result.expectErr(403);
    }
});

Clarinet.test({
    name: "Ensure efficiency score is calculated correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        // Create route
        let block = chain.mineBlock([
            createRoute(deployer, validStops, 1000, 120, vehicleType)
        ]);
        
        // Get metrics and verify score calculation
        const metrics = getRouteMetrics(chain, "u0");
        // Score = (distance * 2) + (num_stops * 100) + time
        const expectedScore = (1000 * 2) + (2 * 100) + 120;
        assertEquals(metrics.efficiency_score, expectedScore);
    }
});
