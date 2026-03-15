# frozen_string_literal: true

require_relative "page_objects/components/audioroom_sidebar"

describe "Audioroom voice rooms", type: :system do
  let(:audioroom_sidebar) { PageObjects::Components::AudioroomSidebar.new }

  fab!(:user)
  fab!(:admin)

  before do
    user.activate
    SiteSetting.audioroom_enabled = true
    SiteSetting.audioroom_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.audioroom_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  context "when plugin is disabled" do
    it "does not show voice rooms section" do
      SiteSetting.audioroom_enabled = false
      Fabricate(:audioroom_room, name: "Test Room", creator: admin, public: true)
      sign_in(user)

      visit("/latest")

      expect(audioroom_sidebar).to be_not_visible
    end
  end

  context "when plugin is enabled" do
    context "as anonymous user" do
      it "does not show voice rooms section" do
        Fabricate(:audioroom_room, name: "Test Room", creator: admin, public: true)

        visit("/latest")

        expect(audioroom_sidebar).to be_not_visible
      end
    end

    context "as logged in user" do
      fab!(:room) { Fabricate(:audioroom_room, name: "Test Room", creator: admin, public: true) }

      before do
        user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!
        sign_in(user)
      end

      it "shows voice rooms section when rooms exist" do
        visit("/latest")

        expect(audioroom_sidebar).to be_visible
      end

      it "displays public rooms in the sidebar" do
        visit("/latest")

        expect(audioroom_sidebar).to be_visible
        expect(audioroom_sidebar).to have_room(room.name)
      end

      it "shows private rooms when user can manage rooms" do
        private_room = Fabricate(:audioroom_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        # Users with sufficient trust level can see and manage all rooms, including private ones
        expect(audioroom_sidebar).to have_room(room.name)
        expect(audioroom_sidebar).to have_room(private_room.name)
      end
    end

    context "as admin" do
      before do
        admin.activate
        sign_in(admin)
      end

      it "shows voice rooms section when rooms exist" do
        Fabricate(:audioroom_room, name: "Admin Room", creator: admin, public: true)

        visit("/latest")

        expect(audioroom_sidebar).to be_visible
      end
    end

    context "when user is not in create room groups" do
      fab!(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      before do
        low_trust_user.activate
        SiteSetting.audioroom_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
        sign_in(low_trust_user)
      end

      it "shows public rooms but hides private rooms" do
        public_room = Fabricate(:audioroom_room, name: "Public Room", creator: admin, public: true)
        private_room = Fabricate(:audioroom_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        expect(audioroom_sidebar).to be_visible
        expect(audioroom_sidebar).to have_room(public_room.name)
        expect(audioroom_sidebar).to have_no_room(private_room.name)
      end
    end
  end
end
