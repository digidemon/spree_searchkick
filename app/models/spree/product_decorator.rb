Spree::Product.class_eval do
  
  if ActiveRecord::Base.connection.table_exists? 'spree_property_translations'
    searchkick ({
      index_prefix: Rails.configuration.elasticsearch_index_name.nil? ? "" : Rails.configuration.elasticsearch_index_name,
      callbacks: :async,
      word_start: ([:name] << Spree::Property.all.map { |prop| prop.name.downcase.to_sym}).flatten!,
      searchable: ([:name, :sku] << Spree::Property.all.map { |prop| prop.name.downcase.to_sym}).flatten!,
      settings: ({ number_of_replicas: 0, 'index.mapping.total_fields.limit': 5000 } unless respond_to?(:searchkick_index))
    })
  end
  
  def self.autocomplete_fields
    [:name]
  end

  def self.search_fields
    [:name]
  end

  def search_data
    json = {
      name: name,
      description: description,
      active: available?,
      created_at: created_at,
      updated_at: updated_at,
      price: price,
      currency: currency,
      conversions: orders.complete.count,
      taxon_ids: taxon_and_ancestors.map(&:id),
      taxon_names: taxon_and_ancestors.map(&:name)
    }

    props = {}
    product_properties.each { |p| props[p.property.name] = p.value.split("/~n").map(&:strip) if p.property && p.value }
    json.merge!(props)

    # TODO - refactor this block like in product_properties
    Spree::Taxonomy.all.each do |taxonomy|
      json.merge!(Hash["#{taxonomy.name.downcase}_ids", taxon_by_taxonomy(taxonomy.id).map(&:id)])
    end

    json
  end

  def taxon_by_taxonomy(taxonomy_id)
    taxons.joins(:taxonomy).where(spree_taxonomies: { id: taxonomy_id })
  end

  def self.autocomplete(keywords)
    if keywords
      Spree::Product.search(
        keywords,
        fields: autocomplete_fields,
        match: :word_start,
        limit: 10,
        load: false,
        misspellings: { below: 3 },
        where: search_where
      ).map(&:name).map(&:strip).uniq
    else
      Spree::Product.search(
        '*',
        fields: autocomplete_fields,
        load: false,
        misspellings: { below: 3 },
        where: search_where
      ).map(&:name).map(&:strip)
    end
  end

  def self.search_where
    {
      active: true,
      price: { not: nil }
    }
  end
end
