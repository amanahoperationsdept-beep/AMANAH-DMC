const products = [
  {
    name: "Glutagen CEE",
    category: "Beauty & wellness",
    detail: "Glutathione, collagen and sodium ascorbate",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_erqnc3erqnc3erqn.jpg",
  },
  {
    name: "Baskug Coffee",
    category: "Herbal coffee",
    detail: "Tongkat ali, maca and Agaricus blazei",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_jybv4xjybv4xjybv.jpg",
  },
  {
    name: "AMANAH Herbal Oil",
    category: "Topical herbal care",
    detail: "Available in 10 ml and 60 ml bottles",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_mjmdqumjmdqumjmd.jpg",
  },
  {
    name: "Barakah Green Coffee Mix",
    category: "Coffee & wellness",
    detail: "Green coffee blend with L-carnitine",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_s9qnxps9qnxps9qn.jpg",
  },
  {
    name: "AMANAH Herbal Rub",
    category: "Topical herbal care",
    detail: "Cooling and soothing herbal rub",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_toe9wxtoe9wxtoe9.jpg",
  },
  {
    name: "Serpentina",
    category: "Botanical supplement",
    detail: "Andrographis paniculata · 50 capsules",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_ut2yd8ut2yd8ut2y.jpg",
  },
  {
    name: "Spirulina",
    category: "Nutritional supplement",
    detail: "Blue-green algae · 100 tablets",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_vm18ixvm18ixvm18.jpg",
  },
  {
    name: "Max C Pro",
    category: "Vitamins & minerals",
    detail: "Daily vitamins, minerals and antioxidant nutrition",
    image: "https://bqgxvnrgjmngezknqhsl.supabase.co/storage/v1/object/public/products/Gemini_Generated_Image_vt2wfmvt2wfmvt2w.jpg",
  },
];

export default function ProductCatalog() {
  return (
    <section className="product-catalog">
      <div className="product-catalog-heading">
        <div>
          <span className="section-kicker">AMANAH PRODUCT MANAGEMENT</span>
          <h2>Product catalog</h2>
          <p>Manage the products available across the AMANAH network.</p>
        </div>
        <span className="product-count">{products.length} products</span>
      </div>
      <div className="product-catalog-grid">
        {products.map((product) => (
          <article className="product-catalog-card" key={product.name}>
            <div className="product-image-wrap">
              {/* Public product image hosted in the AMANAH Supabase Storage bucket. */}
              <img src={product.image} alt={product.name} loading="lazy" />
            </div>
            <div className="product-card-copy">
              <span className="product-category">{product.category}</span>
              <h3>{product.name}</h3>
              <p>{product.detail}</p>
              <div className="product-card-meta">
                <span>Price <strong>Not set</strong></span>
                <span>PV <strong>Not set</strong></span>
              </div>
            </div>
          </article>
        ))}
      </div>
      <p className="product-catalog-note">Product prices and PV values are intentionally left blank until confirmed by an authorized administrator.</p>
    </section>
  );
}
