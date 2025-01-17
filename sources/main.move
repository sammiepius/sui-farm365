module farm::farm {
// use sui::object::{Self, UID, ID};
use std::string::{String};
use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
use std::option::{none,some};
use sui::sui::SUI;
use sui::event;

//define errors codes
const ONLYOWNER:u64=0;
const ITEMEDOESNOTEXISTS:u64=1;
const MUSTBEREGISTERED:u64=2;
const INSUFFICIENTBALANCE:u64=3;
const ITEMALREADYSOLD:u64=4;
const ITEMALREADYRENTED:u64=5;
const ALREADYREFUNDED:u64=6;
const INVALIDRATING:u64=7;

//define user data types

public struct Farm has store,key{
    id:UID,
    name:String,
    farmid:ID,
    balance:Balance<SUI>,
    rating: Option<u64>,
    items:vector<ItemForRent>,
    rented:vector<Renteditem>,
    refunds:vector<RefundRequest>,
    registeredusers:vector<User>,
    boughtitems:vector<BoughtItems>,
   
}

public struct Renteditem has store{
    id:u64,
    itemid:u64,
    userid:u64,
    refunded:bool
}

// struct for Items brought
public struct BoughtItems has store{
    id:u64,
    itemid:u64,
    userid:u64
}

public struct RefundRequest has store{
    id:u64,
    userid:u64,
    itemid:u64,
    resolved:bool,
    buyersaddress:address
}

//struct for items for rent
public struct ItemForRent has store,drop{
    id:u64,
    nameofitem:String,
    description:String,
    image:String,
    price:u64,
    sold:bool,
    rented:bool,
}

public struct User has store{
    id:u64,
    nameofuser:String
}

//define admin capabailitiess
public struct AdminCap has key{
    id:UID, //Unique identifier for the admin
    farmid:ID //The ID of the relief center associated with the admin
}


// Event struct when a farm item is added
public struct ItemAdded has copy,drop{
    id:u64,
    name:String
}

// struct for price update 
public struct PriceUpdated has copy,drop{
    name:String,
    newprice:u64
}
// struct for Description update 
public struct DescriptionUpdated has copy,drop{
    name:String,
    newdescription:String
}

// struct for users registration
public struct UserRegistered  has copy,drop{
    name:String,
    id:u64
}

//struct for item piad
public struct Paid  has copy,drop{
    name:String,
    id:u64
}
//struct for rented item
public struct RentedItem has copy,drop{
    name:String,
    by:u64
}


// create farm
public entry fun create_farm( name: String, ctx: &mut TxContext ) {
    let id=object::new(ctx);
    let farmid=object::uid_to_inner(&id);

        // Initialize a new farm object
    let newfarm = Farm {
        id,
        name,
        farmid:farmid,
        balance:zero<SUI>(),
        rating: none(),
        items:vector::empty(),
        rented:vector::empty(),
        refunds:vector::empty(),    
        registeredusers:vector::empty(),
        boughtitems:vector::empty()        
        };

  // Create the AdminCap associated with the farm
    let admin_cap = AdminCap {
        id: object::new(ctx),  // Generate a new UID for AdminCap
        farmid,  // Associate the farm ID
        };

        // Transfer the admin capability to the sender
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        
        transfer::share_object(newfarm);
}

//add farm items to a farm
public entry fun add_equipment(farm:&mut Farm,nameofitem:String,description:String,image:String,price:u64,owner:&AdminCap){

    //verify that its only the admin can add items
    assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);
    let id:u64=farm.items.length();
    //create a new item
    let newitem=ItemForRent{
        id,
        nameofitem,
        description,
        image,
        price,
        sold:false,
        rented:false,
    };
    farm.items.push_back(newitem);

     event::emit(ItemAdded{
        name:nameofitem,
        id
    });

}


// update the price of an item in a farm
public entry fun update_item_price(farm:&mut Farm,itemid:u64,newprice:u64,owner:&AdminCap){

    //check that its the owner performing the action
     assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);

     //check that item exists
     assert!(itemid<=farm.items.length(),ITEMEDOESNOTEXISTS);

     farm.items[itemid].price=newprice;


     event::emit(PriceUpdated{
        name:farm.items[itemid].nameofitem,
        newprice
    });
}

// update the description of an equipment in a farm
public entry fun update_item_Description(farm:&mut Farm,itemid:u64,newdescription:String,owner:&AdminCap){

    //check that its the owner performing the action
     assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);

     //check that item exists
     assert!(itemid<=farm.items.length(),ITEMEDOESNOTEXISTS);

     farm.items[itemid].description=newdescription;


     event::emit(DescriptionUpdated{
        name:farm.items[itemid].nameofitem,
        newdescription
    });
}

//register a user to a farm
public entry fun register_user(nameofuser:String,farm:&mut Farm){

    //verify that username is unique
    let mut startindex:u64=0;
    let totaluserslength=farm.registeredusers.length();

    while(startindex < totaluserslength){
        let user=&farm.registeredusers[startindex];

        if(user.nameofuser==nameofuser){
            abort 0
        };

        startindex=startindex+1;
    };

    //register new users
    let newuser=User{
        id:totaluserslength,
        nameofuser,
    };
    farm.registeredusers.push_back(newuser);
     event::emit(UserRegistered{
        name:nameofuser,
        id:totaluserslength
    });
}

//purchase an item from a farm
public entry fun purchase_equipment(farm:&mut Farm,itemid:u64,userid:u64,payment:&mut Coin<SUI>,ctx:&mut TxContext){
    //verify that item actually exists 
    assert!(itemid<=farm.items.length(),ITEMEDOESNOTEXISTS);

    //verify that user is already registered
    assert!(userid<=farm.registeredusers.length(),MUSTBEREGISTERED);

    //verify the amount is greater than the price
    assert!(payment.value() >= farm.items[itemid].price,INSUFFICIENTBALANCE);

    //verify that item is not sold
    assert!(farm.items[itemid].sold==false,ITEMALREADYSOLD);

    //verify that item is not rented
    assert!(farm.items[itemid].rented==false,ITEMALREADYRENTED);

    //purchase the item
    let payitem=payment.split(farm.items[itemid].price,ctx);

    put(&mut farm.balance,payitem);
    let id:u64=farm.boughtitems.length();

    let boughtitem=BoughtItems{
        id,
        itemid,
        userid
    };
    //update items status to sold
    farm.items[itemid].sold=true;
    farm.boughtitems.push_back(boughtitem);
    event::emit(Paid{
        name:farm.items[itemid].nameofitem,
        id
    });
}

//rent an item from a farm
public entry fun rent_equipment(farm:&mut Farm,itemid:u64,userid:u64,payment:&mut Coin<SUI>,ctx:&mut TxContext){
    //verify that item actually exists 
    assert!(itemid<=farm.items.length(),ITEMEDOESNOTEXISTS);

    //verify that user is already registered
    assert!(userid<=farm.registeredusers.length(),MUSTBEREGISTERED);

    //verify the amount is greater than the price
    assert!(payment.value() >= (farm.items[itemid].price*2),INSUFFICIENTBALANCE);

    //verify that item is not sold
    assert!(farm.items[itemid].sold==false,ITEMALREADYSOLD);

    //verify that item is not rented
    assert!(farm.items[itemid].rented==false,ITEMALREADYRENTED);

    //purchase the item
    let payitem=payment.split(farm.items[itemid].price,ctx);

    put(&mut farm.balance,payitem);
    let id:u64=farm.boughtitems.length();

    let renteditem=Renteditem{
        id,
        itemid,
        userid,
        refunded:false
    };
    farm.rented.push_back(renteditem);
    //update items status
    farm.items[itemid].rented=true;
    event::emit(RentedItem{
        name:farm.items[itemid].nameofitem,
        by:userid
    });
}

//admin approves refund request of the deposit
public entry fun deposit_refund(farm:&mut Farm,refundid:u64,amount:u64,owner:&AdminCap,ctx:&mut TxContext){

    //verify ist the admin performing the action
    assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);
    //verify that the refund is not resolved
    assert!(farm.refunds[refundid].resolved==false,ALREADYREFUNDED);
    //verify the store has sufficient balance to perform the refund
    // let _itemid=&farm.refunds[refundid].itemid;

     let refundamount = take(&mut farm.balance, amount, ctx);
     transfer::public_transfer(refundamount, farm.refunds[refundid].buyersaddress);  
       

    farm.refunds[refundid].resolved=true;
}

//return rented farm item
public entry fun return_rented_equipment(farm:&mut Farm,userid:u64,itemid:u64,buyersaddress:address){
    //verify that items is rented

    let mut index:u64=0;
    let totalrenteditems=farm.rented.length();

    while(index < totalrenteditems){
        let item=&farm.rented[index];
        if(item.itemid==itemid && item.userid==userid){
            //request refund of deposits
            let id=farm.refunds.length();
            let newrefundrequest=RefundRequest{
                 id,
                 userid,
                 itemid,
                 resolved:false,
                 buyersaddress
            };
            farm.refunds.push_back(newrefundrequest);
            //update details of refunded item
            farm.items[itemid].rented=false;
        };
        index=index+1;
    }
}


  // Rate the Farm
public entry fun rate_farm(farm: &mut Farm, rating: u64) {
    // assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);
    assert!(rating >0 && rating < 10,INVALIDRATING);
    farm.rating = some(rating);
}


// get farm items details using the item id
public fun view_item_details(farm: &Farm, itemid: u64) : (u64, String, String, String, u64, bool, bool) {
    let item = &farm.items[itemid];
     (
        item.id,
        item.nameofitem,
        item.description,
        item.image,
        item.price,
        item.sold,
        item.rented,
    )
}

// getter function that gets users by id
public fun get_user_details(farm: &Farm, userid: u64) : (u64, String) {
    let user = &farm.registeredusers[userid];
    (
        user.id,
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
          assert!(amount > 0 && amount <= farm.balance.value(), INSUFFICIENTBALANCE);
          //verify the admin performing the action
          assert!(&owner.farmid == object::uid_as_inner(&farm.id),ONLYOWNER);
        let takeamount = take(&mut farm.balance, amount, ctx);  
        transfer::public_transfer(takeamount, recipient);
       
    }


}
