module farm::farm {
// use sui::object::{Self, UID, ID};
use std::string::{String};
use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
use std::option::{none,some};
use sui::sui::SUI;
use sui::event;
use sui::bag;
//define errors codes
const EOnlyOwner:u64=0;
const EItemDoesNotExist:u64=1;
const EInsufficientFunds:u64=3;
const EItemAlreadyRented:u64=5;
//define user data types

public struct Farm has store, key{
    id:UID,
    name:String,
    farmid:ID,
    balance:Balance<SUI>,
    rating: Option<u64>,
    items: bag::Bag,
}

public struct RentedItem has key, store {
    id: UID,
    itemid: ID,
}





//struct for items for rent
public struct Item has key, store{
    id: UID,
    nameofitem:String,
    description:String,
    image:String,
    price:u64,
    rented_by:Option<address>,
}

public struct User has key, store{
    id: UID,
    nameofuser: String,
    address: address
}

//define admin capabailitiess
public struct AdminCap has key, store {
    id:UID, //Unique identifier for the admin
    farmid:ID //The ID of the relief center associated with the admin
}

/* === Events === */

// Event struct when a farm item is added
public struct ItemAdded has copy, drop{
    id: ID,
    name:String
}

// struct for price update 
public struct PriceUpdated has copy, drop{
    name: String,
    newprice: u64
}

// struct for users registration
public struct UserRegistered  has copy, drop{
    name:String,
    id: ID
}

//struct for rented item
public struct ItemRented has copy, drop{
    name:String,
    by: address
}


public struct ItemReturned has copy, drop {
    name: String,
    by: address
}

public struct BoughtItem has copy, drop{
    name: String,
    id: ID
}

// create farm
public fun create_farm( name: String, ctx: &mut TxContext ): AdminCap {
    let id = object::new(ctx);
    let farmid = object::uid_to_inner(&id);

        // Initialize a new farm object
    let newfarm = Farm {
        id,
        name,
        farmid:farmid,
        balance:zero<SUI>(),
        rating: none(),
        items: bag::new(ctx)
    };
             
    transfer::share_object(newfarm);

  // Create the AdminCap associated with the farm
    AdminCap {
        id: object::new(ctx),  // Generate a new UID for AdminCap
        farmid,  // Associate the farm ID
    }   
}

//add farm items to a farm
public entry fun add_equipment(farm:&mut Farm,nameofitem:String,description:String,image:String,price:u64,owner:&AdminCap, ctx: &mut TxContext){

    //verify that its only the admin can add items
    assert!(&owner.farmid == object::uid_as_inner(&farm.id), EOnlyOwner);
    //create a new item
    let newitem= Item{
        id: object::new(ctx),
        nameofitem,
        description,
        image,
        price,
        rented_by: none<address>(),
    };

    let id = object::id(&newitem);

    farm.items.add(id, newitem);

     event::emit(ItemAdded{
        name:nameofitem,
        id
    });

}


// update the price of an item in a farm
public entry fun update_item_price(farm:&mut Farm,itemid:ID,newprice:u64,owner:&AdminCap){

    //check that its the owner performing the action
    assert!(&owner.farmid == object::uid_as_inner(&farm.id),EOnlyOwner);

    // check that item exists
    assert!(farm.items.contains(itemid),EItemDoesNotExist);


    let item = farm.items.borrow_mut<ID, Item>(itemid);
    item.price = newprice;


     event::emit(PriceUpdated{
        name: item.nameofitem,
        newprice
    });
}

//register a user to a farm
public fun register_user(nameofuser:String, ctx: &mut TxContext): User{

    //verify that username is unique
    //register new users
    let newuser=User{
        id: object::new(ctx),
        nameofuser,
        address: ctx.sender()
    };
     event::emit(UserRegistered{
        name:nameofuser,
        id: object::id(&newuser)
    });

    newuser
}

//purchase an item from a farm
public fun purchase_equipment(farm:&mut Farm, itemid: ID, _: &User, payment: &mut Coin<SUI>, ctx: &mut TxContext): Item {
    //verify that item actually exists 
    
    assert!(farm.items.contains(itemid),EItemDoesNotExist);


    let item = farm.items.remove<ID, Item>(itemid);
    //verify the amount is greater than the price
    assert!(payment.value() >= item.price, EInsufficientFunds);


    //verify that item is not rented
    assert!(item.rented_by.is_none(),EItemAlreadyRented);

    //purchase the item
    let payitem = payment.split(item.price, ctx);

    put(&mut farm.balance,payitem);

    //update items status to sold
    event::emit(BoughtItem {
        name: *&item.nameofitem,
        id: object::id(&item)
    });

    item
}

//rent an item from a farm
public fun rent_equipment(farm:&mut Farm, itemid: ID, user: &User, payment: &mut Coin<SUI>,ctx:&mut TxContext): RentedItem {
   //verify that item actually exists 
    assert!(farm.items.contains(itemid),EItemDoesNotExist);


    let item = farm.items.borrow_mut<ID, Item>(itemid);
    //verify the amount is greater than the price
    assert!(payment.value() >= item.price, EInsufficientFunds);


    //verify that item is not rented
    assert!(item.rented_by.is_none(), EItemAlreadyRented);

    //purchase the item
    let payitem = payment.split(item.price, ctx);

    put(&mut farm.balance,payitem);


    //update items status
    item.rented_by.fill<address>(user.address);

    event::emit(ItemRented {
        name: item.nameofitem,
        by: user.address
    });

    RentedItem {
        id: object::new(ctx),
        itemid: object::id(item)
    }
}


//return rented farm item
public fun return_rented_equipment(farm:&mut Farm, user : &User, rent_item: RentedItem){
    //verify that items is rented
    let RentedItem { id, itemid } = rent_item;

    if (farm.items.contains(itemid)) {
        let item = farm.items.borrow_mut<ID, Item>(itemid);

        item.rented_by.extract<address>();

        event::emit(ItemReturned {
            name: item.nameofitem,
            by: user.address
        });
    };

    id.delete();
}


//   Rate the Farm
public entry fun rate_farm(farm: &mut Farm, rating: u64, owner:&AdminCap) {
    assert!(&owner.farmid == object::uid_as_inner(&farm.id),EOnlyOwner);
    farm.rating = some(rating);
}


// get farm items details using the item id
public fun view_item_details(farm: &Farm, itemid: ID) : (ID, String, String, String, u64, Option<address>) {

    assert!(farm.items.contains(itemid), EItemDoesNotExist);

    let item = farm.items.borrow<ID,Item>(itemid);
     (
        itemid,
        item.nameofitem,
        item.description,
        item.image,
        item.price,
        item.rented_by,
    )
}

// getter function that gets users by id
public fun get_user_details(user: &User) : (ID, String) {
    (
        object::id(user),
        user.nameofuser,
    )
}

// Get the balance of a farm
public fun get_farm_balance(farm: &Farm): u64 {
        farm.balance.value()  
    }


//owner witdraw amounts
 public entry fun withdraw_funds(
        farm: &mut Farm,   
        owner: &AdminCap,
        amount:u64,
        recipient:address,
         ctx: &mut TxContext,
    ) {

        //verify amount
          assert!(amount > 0 && amount <= farm.balance.value(), EInsufficientFunds);
          //verify the admin performing the action
          assert!(&owner.farmid == object::uid_as_inner(&farm.id),EOnlyOwner);
        let takeamount = take(&mut farm.balance, amount, ctx);  
        transfer::public_transfer(takeamount, recipient);
       
}

#[test_only]
public fun id_from_event(e: ItemAdded): ID {
        e.id
}
}
