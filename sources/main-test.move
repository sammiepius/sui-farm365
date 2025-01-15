#[test_only]
module farm::farm_test {
    use farm::farm::{Self, Farm, AdminCap, User, ItemAdded, RentedItem};
    use sui::test_scenario::{Self as ts, ctx, Scenario, next_tx};
    use sui::event;
    use sui::coin::mint_for_testing;
    use sui::sui::SUI;
    // use std::debug;

    const ADDR: address = @0xA;
    const USR: address = @0xB;

    fun create_farm_for_testing(sender: address): Scenario {
        let mut scenario = ts::begin(sender);
        {
            let admin_cap = farm::create_farm(b"Test farm".to_string(), ctx(&mut scenario));
            transfer::public_transfer(admin_cap, sender);
        };
        next_tx(&mut scenario, sender);

        scenario
    }

    fun add_item_for_testing(scenario: &mut Scenario): ID {
        let mut farm = ts::take_shared<Farm>(scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(scenario);

        farm::add_equipment(&mut farm, b"name_test".to_string(), b"desc".to_string(), b"img".to_string(), 10_000, &admin_cap, ctx(scenario));

        ts::return_shared(farm);
        ts::return_to_address(ADDR, admin_cap);
        
        let itemid = farm::id_from_event((event::events_by_type<ItemAdded>()).pop_back());
        // debug::print<ItemAdded>(&(event::events_by_type<ItemAdded>()).pop_back());         
        // debug::print<ID>(&itemid);
        itemid
    }

    #[test]
    fun test_create_farm() {
        let mut scenario = ts::begin(ADDR);
        {
            let admin_cap = farm::create_farm(b"Test farm".to_string(), ctx(&mut scenario));
            transfer::public_transfer(admin_cap, ADDR);
        };
        next_tx(&mut scenario, ADDR);
        {
            let farm = ts::take_shared<Farm>(&scenario);
            ts::return_shared(farm);
        };
        ts::end(scenario);
    }
    // Test Create_farm
    // Test Add Farm Tool
    #[test]
    fun test_add_equipment() {
        let mut scenario = create_farm_for_testing(ADDR);
        {
            let mut farm = ts::take_shared<Farm>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            farm::add_equipment(&mut farm, b"name_test".to_string(), b"desc".to_string(), b"img".to_string(), 10_000, &admin_cap, ctx(&mut scenario));

            ts::return_shared(farm);
            ts::return_to_address(ADDR, admin_cap);
        };

        ts::end(scenario);
    }
    // Register User
    #[test]
    fun test_register_user() {
        let mut scenario = create_farm_for_testing(ADDR);
        {
            let user_cap = farm::register_user(b"user name".to_string(),ctx(&mut scenario));
            transfer::public_transfer(user_cap, ADDR);
        };
        ts::end(scenario);
    }

    // Buy Item
    #[test]
    fun test_purchase_equipment() {
        let mut scenario = create_farm_for_testing(ADDR);
        // create a farm Item
        let itemid = add_item_for_testing(&mut scenario);

        // Register a user
        next_tx(&mut scenario, USR);
        {
            let user_cap = farm::register_user(b"user name".to_string(),ctx(&mut scenario));
            transfer::public_transfer(user_cap, USR);
        };

        // Purchase Item
        next_tx(&mut scenario, USR);
        {
            let mut farm = ts::take_shared<Farm>(&scenario);
            let user_cap = ts::take_from_sender<User>(&scenario);
            let mut coin = mint_for_testing<SUI>(10_000_000, ctx(&mut scenario));

            
            
            let item = farm::purchase_equipment(
                &mut farm, 
                itemid, 
                &user_cap, 
                &mut coin, 
                ctx(&mut scenario));

            coin.burn_for_testing();
            ts::return_shared(farm);
            ts::return_to_address(USR, user_cap);
            transfer::public_transfer(item, USR);
        };

        ts::end(scenario);
    }

    // Borrow Item
    #[test]
    fun test_rent_return_equipment() {
        let mut scenario = create_farm_for_testing(ADDR);
        // create a farm Item
        let itemid = add_item_for_testing(&mut scenario);

        // Register a user
        next_tx(&mut scenario, USR);
        {
            let user_cap = farm::register_user(b"user name".to_string(),ctx(&mut scenario));
            transfer::public_transfer(user_cap, USR);
        };

        // Rent item
        next_tx(&mut scenario, USR);
        {
            let mut farm = ts::take_shared<Farm>(&scenario);
            let user_cap = ts::take_from_sender<User>(&scenario);
            let mut coin = mint_for_testing<SUI>(10_000_000, ctx(&mut scenario));

            
            
            let item = farm::rent_equipment(
                &mut farm, 
                itemid, 
                &user_cap, 
                &mut coin, 
                ctx(&mut scenario));

            coin.burn_for_testing();
            transfer::public_transfer(item, USR);
            ts::return_shared(farm);
            ts::return_to_address(USR, user_cap);
        };

        // Return item
        next_tx(&mut scenario, USR);
        {
            let mut farm = ts::take_shared<Farm>(&scenario);
            let user_cap = ts::take_from_sender<User>(&scenario);
            let item = ts::take_from_sender<RentedItem>(&scenario);

            farm::return_rented_equipment(&mut farm, &user_cap, item);

            ts::return_shared(farm);
            ts::return_to_address(USR, user_cap);
        };
        ts::end(scenario);
    }
}