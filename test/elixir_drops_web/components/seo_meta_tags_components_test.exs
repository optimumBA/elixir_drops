defmodule ElixirDropsWeb.SeoMetaTagsComponentsTest do
  use ElixirDropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ElixirDropsWeb.SeoMetaTagsComponent

  describe "seo_meta_tags/1" do
    test "renders meta tags with the values passed" do
      assigns = %{
        description: "Test description",
        title: "Elixir Drops"
      }

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: assigns) =~
               "<meta name=\"twitter:card\" content=\"summary_large_image\">\n"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: assigns) =~
               "<meta name=\"twitter:site\" content=\"@optimumBA\">\n"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: assigns) =~
               "<meta property=\"description\" content=\"Test description\">\n"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: assigns) =~
               "<meta property=\"og:description\" content=\"Test description\">\n"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: assigns) =~
               "<meta property=\"og:title\" content=\"Elixir Drops\">"
    end

    test "renders meta tags with default values if no attributes are given" do
      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta name=\"twitter:card\" content=\"summary_large_image\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta name=\"twitter:description\" content=\"Share Elixir tips and tricks with the community...\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta name=\"twitter:image\" content=\"http://localhost:4002/images/seo_default_image.png\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta name=\"twitter:site\" content=\"@optimumBA\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta name=\"twitter:url\" content=\"http://localhost:4002/\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"description\" content=\"Share Elixir tips and tricks with the community...\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"og:description\" content=\"Share Elixir tips and tricks with the community...\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"og:image\" content=\"http://localhost:4002/images/seo_default_image.png\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"og:title\" content=\"Elixir Drops\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"og:type\" content=\"website\">"

      assert render_component(&SeoMetaTagsComponent.seo_meta_tags/1, attributes: nil) =~
               "<meta property=\"og:url\" content=\"http://localhost:4002/\">"
    end
  end
end
