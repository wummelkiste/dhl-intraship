# Dhl::Intraship

This is a simple gem to wrap the DHL Intraship SOAP Api. Note that currently only "national day definite shipment" usecases are implemented  (Sending, deleting and manifesting national day definite packages without any extra services.)
Booking a pickup is implemented as prototype, but not yet supported by DHL itself.

## Installation

Add this line to your application's Gemfile:

    gem 'dhl-intraship'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dhl-intraship

## Usage

Initialize a new API object using

```ruby
api = Dhl::Intraship::API.new(config, options)
```

Config is the following hash:

```ruby
config = {
  user: 'your Intraship API user name', #mandatory
  signature: 'Your Intraship API user password', #mandatory
  ekp: 'Your DHL EKP (first part of your DHL Account number)', #mandatory
  procedure_id: 'The prodedureId (second part of your DHL Account number)', #optional, defaults to '01'
  partner_id: 'The partnerId (=attendance, third part of your DHL Account number)' #optional, defaults to '01'
}
```

Options is an optional parameter and can contain the following parameters:

```ruby
options = {
 test: true, # If test is set, all API calls go against the Intraship test system
 label_response_type: :xml # If it's set to XML the createShipment-Calls return the label data as XML instead of the PDF-Link
}
```

### Create a shipment

To create a shipment to DHL you need to create it first


```ruby
sender_address =
 Dhl::Intraship::CompanyAddress.new(company: 'Team Europe Ventures',
                                    contact_person: 'John Smith',
                                    street: 'Mohrenstraße',
                                    house_number: '60',
                                    zip: '10117',
                                    city: 'Berlin',
                                    country_code: 'DE',
                                    email: 'info@teameurope.net')

receiver_address =
  Dhl::Intraship::PersonAddress.new(firstname: 'John',
                                    lastname: 'Doe',
                                    street: 'Mainstreet',
                                    house_number: '10',
                                    street_additional: 'Appartment 2a',
                                    zip: '90210',
                                    city: 'Springfield',
                                    country_code: 'DE',
                                    email: 'john.doe@example.com')

# Use can use multiple parcels per shipment. Note that the weight
# parameter is in kg and the length/height/width in cm
shipment_item =
  Dhl::Intraship::ShipmentItem.new(weight: 3,
                                   length: 120,
                                   width:  60,
                                   height: 60)

shipment =
  Dhl::Intraship::Shipment.new(sender_address: sender_address,
                               receiver_address: receiver_address,
                               shipment_items: shipment_item # give array for multiple parcel shipment
                               shipment_date: Date.today)
```

Beware, that due to DHL Intraship restrictions, the sender address
must be a CompanyAddress and requires a contact_person.  The actual
api-call takes an array of shipments, or a single shipment.  The
result contains the "shipment_number", as well as the "label_url" (or
the "xml_label" when it was specified as repsonse type)

```ruby
result = api.createShipmentDD(shipment)
shipment_number = result[:shipment_number]
label_url = result[:label_url] # Or result[:xml_label] in case XML label was set in the options
```
#### Deliver DHL Domestic Express Shipments

If your DHL Intraship Account can deliver DHL Express shipments, you have to do the following

```ruby
shipment.product_code = Dhl::Intraship::ProductCode::DHL_DOMESTIC_EXPRESS # will set the product code to EXP
express_service = Dhl::Intraship::DhlExpressService.new(Dhl::Intraship::DhlExpressService::EXPRESS1200)
# You can choose between following possible service options:
# DeliveryOnTime DeliveryEarly Express0900 Express1000 Express1200 DeliveryAfternoon DeliveryEvening ExpressSaturday ExpressSunday
# If you are using the DeliveryOnTime service, you have to set the delivery time (format 'hh:mm'):
express_service = Dhl::Intraship::DhlExpressService.new(Dhl::Intraship::DhlExpressService::DELIVERY_ON_TIME, '14:00')
shipment.add_service(express_service)
```

If the DHL Intraship Webservice returns: `1102 - Service 'SERVICE_ERT'
is not allowed for productcode 'EXP'`
your intraship account have not enough permissions to deliver 
express shipments (maybe also multi parcel shipment is not permitted).

#### Add cash on delivery

For the "cash on delivery" service you need to create a Bankdata object with the payee information.
Give that together with the amount and the currency to a CODService object. Finally add the service to your shipment:

```ruby
bankdata = Dhl::Intraship::Bankdata.new(owner: 'John Smith',
                                        account_number: '1212121212',
                                        bank_code: '12345679',
                                        bank_name: 'Testbank 2',
                                        note: 'OrderID 12345')
cod_service = Dhl::Intraship::CODService.new(amount:  15.00,
                                             currency: 'EUR',
                                             bankdata: bankdata)
shipment.add_service(cod_service)
```

### Delete a shipment

You can create and delete shipments as much as you like, they will not get into the "real" DHL system until you manifest them.
To delete a shipment call deleteShipmentDD with the shipment number for a non-manifested shipment:

```ruby
api.deleteShipmentDD(shipment_number)
```

### Manifesting a shipment

A shipment created in Intraship is only transferred to the "real" DHL systems after the shipment is manifested.
If "manifestShipment" is not called manually, it should be automatically manifested after the time that is configured in the Intraship backend.
To manifest the shipment manually call:

```ruby
api.doManifestDD(shipment_number)
```

*Note that the label has to be downloaded at least once, or Intraship will reply with status code 2030: shipment not printed*

### Booking a pickup

*The "book pickup"-call is defined in the Intraship API and also supported in this gem, but not implemented and supported in Intraship itself*

The API will complain if no "contact orderer" is specified, although it's supposed to be optional. Furthermore issuing a "book pickup" call will yield a  "Please select a product in the shipment details." (1102) error, although the call is completely valid.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
