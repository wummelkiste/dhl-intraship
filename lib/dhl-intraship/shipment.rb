module Dhl
  module Intraship
    class Shipment

      attr_accessor :sender_address, :receiver_address, :shipment_date, :product_code,
                    :customer_reference, :services, :shipment_items, :dhl_express_service

      def initialize(attributes = {})
        self.product_code = ProductCode::DHL_PACKAGE
        self.services = []
        self.shipment_items = []

        # If an initial shipment is given we have to create a new
        # ShipmentItem (for backward compatibility). Maybe we can drop
        # this in a new major release ...
        if attributes.has_key?(:weight) or attributes.has_key?(:length) or
            attributes.has_key?(:width) or attributes.has_key?(:height)
          warn "[DEPRECATION] The single shipment constructor is deprecated, please pass in a ShipmentItem"
          @shipment_items << ShipmentItem.new(attributes)
        else
          @shipment_items.push(*attributes.delete(:shipment_items))
        end

        attributes.each do |key, value|
          setter = :"#{key.to_s}="
          if self.respond_to?(setter)
            self.send(setter, value)
          end
        end
      end

      def add_service(newservice)
        case newservice
        when DhlExpressService
          unless dhl_domestic_express?
          end
        end
        @services << newservice
      end

      def add_shipment_item(shipment_item)
        @shipment_items << shipment_item
      end

      def product_code=(product_code)
        raise "No valid product code #{product_code}" unless ProductCode::VALID_PRODUCT_CODES.include?(product_code)
        @product_code = product_code
      end

      def append_to_xml(ekp, partner_id, xml)
        raise "Shipment date must be set!" if shipment_date.blank?
        raise "Sender address must be set!" if sender_address.blank?
        raise "Receiver address must be set!" if receiver_address.blank?

        add_and_validate_service_dependencies

        xml.Shipment do |xml|
          xml.ShipmentDetails do |xml|
            xml.ProductCode(product_code)
            xml.ShipmentDate(shipment_date.strftime("%Y-%m-%d"))
            xml.cis(:EKP, ekp)
            xml.Attendance do |xml|
              xml.cis(:partnerID, partner_id)
            end
            xml.CustomerReference(customer_reference) unless customer_reference.blank?

            # multiple parcels
            shipment_items.each do |shipment_item|
              shipment_item.append_to_xml(xml)
            end
            services.each do |service|
              service.append_to_xml(xml)
            end
          end
          # Shipper information
          xml.Shipper do |xml|
            sender_address.append_to_xml(xml)
          end
          # Receiver information
          xml.Receiver do |xml|
            receiver_address.append_to_xml(xml)
          end
        end
      end

      private

      def add_and_validate_service_dependencies
        # for using multiple parcels for product code EPN or EXP there
        # is an extra service ServiceGroupDHLPaket.Multipack that
        # needs to be add
        if add_dhl_paket_multipack_service?
          add_service(DhlPaketMultipackService.new)
        end

        if dhl_domestic_express? and not has_service?(HigherInsuranceService)
          # we also need a higher insurance service if not set already
          add_service(HigherInsuranceService.new)
        end

        # check service constraints
        if has_service?(DhlExpressService) and not dhl_domestic_express?
          raise 'The DhlExpressService can only be add to DHL Domestic Express (EXP) shipments.'
        end
      end

      def has_service?(service_class)
        services.map(&:class).include?(service_class)
      end

      def dhl_domestic_express?
        product_code == ProductCode::DHL_DOMESTIC_EXPRESS
      end

      def add_dhl_paket_multipack_service?
        shipment_items.size > 1 and
          product_code == ProductCode::DHL_PACKAGE
      end
    end
  end
end
