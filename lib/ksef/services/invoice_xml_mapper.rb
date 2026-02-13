# frozen_string_literal: true

require "bigdecimal"
require "rexml/document"

module Ksef
  module Services
    class InvoiceXmlMapper
      def initialize(ksef_number:)
        @ksef_number = ksef_number
      end

      def call(xml)
        doc = parse_document(xml)
        items = extract_items(doc)

        seller = {
          "name" => text_from_paths(doc, [%w[Podmiot1 DaneIdentyfikacyjne Nazwa], %w[Invoice AccountingSupplierParty Party PartyName Name]]),
          "nip" => text_from_paths(doc, [%w[Podmiot1 DaneIdentyfikacyjne NIP], %w[Invoice AccountingSupplierParty Party PartyTaxScheme CompanyID]]),
          "address" => address_from_paths(doc, [%w[Podmiot1 Adres], %w[Invoice AccountingSupplierParty Party PostalAddress]])
        }.compact

        buyer = {
          "name" => text_from_paths(doc, [%w[Podmiot2 DaneIdentyfikacyjne Nazwa], %w[Invoice AccountingCustomerParty Party PartyName Name]]),
          "nip" => text_from_paths(doc, [%w[Podmiot2 DaneIdentyfikacyjne NIP], %w[Invoice AccountingCustomerParty Party PartyTaxScheme CompanyID]]),
          "address" => address_from_paths(doc, [%w[Podmiot2 Adres], %w[Invoice AccountingCustomerParty Party PostalAddress]])
        }.compact

        gross_amount_node = node_from_paths(doc, [%w[Invoice LegalMonetaryTotal TaxInclusiveAmount], %w[Fa P_15]])
        net_amount = sum_amount_by_local_name_pattern(doc.root, /^P_13_\d+$/) ||
          text_from_paths(doc, [%w[Invoice LegalMonetaryTotal TaxExclusiveAmount]])
        vat_amount = sum_amount_by_local_name_pattern(doc.root, /^P_14_\d+$/) ||
          text_from_paths(doc, [%w[Invoice TaxTotal TaxAmount]])

        {
          "ksefNumber" => @ksef_number,
          "invoiceNumber" => text_from_paths(doc, [%w[Fa P_2], %w[Invoice ID]]),
          "invoiceType" => text_from_paths(doc, [%w[Fa RodzajFaktury], %w[Invoice InvoiceTypeCode]]),
          "issueDate" => text_from_paths(doc, [%w[Fa P_1], %w[Invoice IssueDate]]),
          "invoicingDate" => text_from_paths(doc, [%w[Fa P_6], %w[Invoice TaxPointDate]]),
          "paymentDueDate" => text_from_paths(doc, [%w[Fa TerminPlatnosci], %w[Fa P_18A], %w[Invoice PaymentMeans PaymentDueDate]]),
          "paymentMethod" => text_from_paths(doc, [%w[Fa FormaPlatnosci], %w[Fa P_18B], %w[Invoice PaymentMeans PaymentMeansCode]]),
          "netAmount" => net_amount,
          "grossAmount" => text_for_node(gross_amount_node),
          "vatAmount" => vat_amount,
          "currency" => text_from_paths(doc, [%w[Fa KodWaluty]]) || currency_from_nodes(gross_amount_node),
          "seller" => seller,
          "buyer" => buyer,
          "items" => items,
          "xml" => xml
        }.compact
      end

      private

      def parse_document(xml)
        REXML::Document.new(xml.to_s)
      rescue REXML::ParseException => e
        raise Ksef::InvoiceError, "Invalid invoice XML: #{e.message}"
      end

      def text_from_paths(doc, paths)
        node = node_from_paths(doc, paths)
        text_for_node(node)
      end

      def text_for_node(node)
        return nil unless node

        value = node.text.to_s.strip
        value.empty? ? nil : value
      end

      def currency_from_nodes(*nodes)
        nodes.each do |node|
          next unless node

          currency = node.attributes["currencyID"].to_s.strip
          return currency unless currency.empty?
        end
        nil
      end

      def address_from_paths(doc, paths)
        address_node = node_from_paths(doc, paths)
        return nil unless address_node

        street = text_from_relative_paths(address_node, [%w[Ulica], %w[StreetName]])
        building_number = text_from_relative_paths(address_node, [%w[NrDomu], %w[BuildingNumber]])
        apartment_number = text_from_relative_paths(address_node, [%w[NrLokalu]])
        postal_code = text_from_relative_paths(address_node, [%w[KodPocztowy], %w[PostalZone]])
        city = text_from_relative_paths(address_node, [%w[Miejscowosc], %w[CityName]])
        post_office = text_from_relative_paths(address_node, [%w[Poczta]])
        municipality = text_from_relative_paths(address_node, [%w[Gmina]])
        county = text_from_relative_paths(address_node, [%w[Powiat]])
        province = text_from_relative_paths(address_node, [%w[Wojewodztwo], %w[CountrySubentity]])
        country = text_from_relative_paths(address_node, [%w[KodKraju], %w[Country IdentificationCode], %w[IdentificationCode], %w[CountryCode]])

        street_line = [street, building_number].compact.join(" ").strip
        unless apartment_number.to_s.strip.empty?
          street_line = street_line.empty? ? apartment_number : "#{street_line}/#{apartment_number}"
        end

        locality_line = [postal_code, city].compact.join(" ").strip
        region_line = [municipality, county, province].compact.join(", ").strip

        parts = [street_line, locality_line, post_office, region_line, country].reject { |value| value.to_s.strip.empty? }
        return nil if parts.empty?

        parts.join(", ")
      end

      def text_from_relative_paths(node, paths)
        paths.each do |path|
          matching_node = node_from_relative_paths(node, [path])
          value = text_for_node(matching_node)
          return value if value
        end

        nil
      end

      def node_from_relative_paths(node, paths)
        paths.each do |path|
          matching_node = find_node_by_local_path(node, path, [local_name(node.name)])
          return matching_node if matching_node
        end

        nil
      end

      def extract_items(doc)
        fa_rows = nodes_by_local_name(doc.root, "FaWiersz")
        items = if fa_rows.any?
          fa_rows.each_with_index.map { |row, index| map_fa_row_item(row, index + 1) }
        else
          ubl_rows = nodes_by_local_name(doc.root, "InvoiceLine")
          ubl_rows.map { |row| map_ubl_item(row) }
        end

        items.compact
      end

      def map_fa_row_item(row, fallback_position)
        item = {
          "position" => text_from_relative_paths(row, [%w[NrWierszaFa], %w[LpFa]]) || fallback_position.to_s,
          "description" => text_from_relative_paths(row, [%w[P_7], %w[NazwaTowaruUslugi]]),
          "quantity" => text_from_relative_paths(row, [%w[P_8B], %w[Ilosc]]),
          "unit" => text_from_relative_paths(row, [%w[P_8A], %w[JednostkaMiary]]),
          "unitPrice" => text_from_relative_paths(row, [%w[P_9A], %w[CenaJednostkowaNetto], %w[CenaJednostkowa]]),
          "netAmount" => text_from_relative_paths(row, [%w[P_11], %w[WartoscNetto]]),
          "vatRate" => text_from_relative_paths(row, [%w[P_12], %w[StawkaPodatku]]),
          "vatAmount" => text_from_relative_paths(row, [%w[P_11Vat], %w[KwotaVat], %w[KwotaPodatku]]),
          "grossAmount" => text_from_relative_paths(row, [%w[P_11A], %w[WartoscBrutto]])
        }.compact

        return nil unless item_has_content?(item)

        item
      end

      def map_ubl_item(row)
        quantity_node = node_from_relative_paths(row, [%w[InvoicedQuantity]])
        quantity = text_for_node(quantity_node)
        unit = quantity_node&.attributes&.[]("unitCode")&.to_s&.strip
        unit = nil if unit&.empty?

        unit_price_node = node_from_relative_paths(row, [%w[Price PriceAmount]])
        net_amount = text_from_relative_paths(row, [%w[LineExtensionAmount]])
        vat_amount = text_from_relative_paths(row, [%w[TaxTotal TaxAmount]])

        item = {
          "position" => text_from_relative_paths(row, [%w[ID]]),
          "description" => text_from_relative_paths(row, [%w[Item Name]]),
          "quantity" => quantity,
          "unit" => unit,
          "unitPrice" => text_for_node(unit_price_node),
          "netAmount" => net_amount,
          "vatRate" => text_from_relative_paths(row, [%w[Item ClassifiedTaxCategory Percent]]),
          "vatAmount" => vat_amount,
          "grossAmount" => sum_amounts(net_amount, vat_amount)
        }.compact

        return nil unless item_has_content?(item)

        item
      end

      def sum_amounts(first, second)
        first_decimal = decimal_value(first)
        second_decimal = decimal_value(second)
        return nil unless first_decimal && second_decimal

        format_decimal(first_decimal + second_decimal)
      end

      def item_has_content?(item)
        keys = %w[description quantity unit unitPrice netAmount vatRate vatAmount grossAmount]
        keys.any? { |key| !item[key].to_s.strip.empty? }
      end

      def nodes_by_local_name(root_node, target_name)
        matches = []
        each_node(root_node) do |node|
          matches << node if local_name(node.name) == target_name
        end
        matches
      end

      def sum_amount_by_local_name_pattern(root_node, pattern)
        sum = BigDecimal(0)
        found = false

        each_node(root_node) do |node|
          next unless local_name(node.name).match?(pattern)

          amount = decimal_value(node.text.to_s)
          next unless amount

          sum += amount
          found = true
        end

        found ? format_decimal(sum) : nil
      end

      def decimal_value(text)
        normalized = text.to_s.strip.tr(",", ".")
        return nil if normalized.empty?

        BigDecimal(normalized)
      rescue ArgumentError
        nil
      end

      def format_decimal(decimal)
        format("%.2f", decimal)
      end

      def each_node(node, &block)
        yield node
        node.elements.each { |child| each_node(child, &block) }
      end

      def node_from_paths(doc, paths)
        paths.each do |path|
          node = find_node_by_local_path(doc.root, path, [local_name(doc.root.name)])
          return node if node
        end
        nil
      end

      def find_node_by_local_path(node, target_path, current_path)
        return node if current_path.last(target_path.length) == target_path

        node.elements.each do |child|
          child_path = current_path + [local_name(child.name)]
          match = find_node_by_local_path(child, target_path, child_path)
          return match if match
        end

        nil
      end

      def local_name(name)
        name.to_s.split(":").last
      end
    end
  end
end
