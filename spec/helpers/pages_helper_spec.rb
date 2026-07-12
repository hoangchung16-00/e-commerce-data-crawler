require 'rails_helper'

RSpec.describe PagesHelper, type: :helper do
  describe "helper methods" do
    it "pages helper is available in view context" do
      expect(helper.class.ancestors).to include(ActionView::Helpers::UrlHelper)
    end
  end
end
