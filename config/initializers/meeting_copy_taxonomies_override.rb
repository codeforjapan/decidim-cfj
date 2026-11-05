# frozen_string_literal: true

# 管理画面のミーティング「複製」が Decidim 0.30.x では必ず 500 になるため、その修正。
#
# Decidim::Meetings::Admin::CopyMeeting は Meeting.create! に
# `taxonomies: form.taxonomies` を渡すが、フォーム側の
# Decidim::HasTaxonomyFormAttributes は `attribute :taxonomies, Array[Integer]`
# を宣言しているため、返るのは Decidim::Taxonomy ではなくタクソノミーの id 配列。
# コンポーネントの設定にタクソノミーフィルタがあると複製フォームに select が出るので、
# 選択の有無に関わらず ActiveRecord::AssociationTypeMismatch になる。
#
#   未選択  -> hidden の空文字が Integer キャストで nil -> "expected, got nil"
#   選択済み -> id がそのまま Integer で渡る            -> "expected, got 18"
#
# CreateMeeting / UpdateMeeting は既に `form.taxonomizations` を使っており、
# ここでも同じものを渡すようにする。
#
# 本家: decidim/decidim#15718 を decidim/decidim#15736 で修正済み。
# v0.31.1 以降に入っているが release/0.30-stable にはバックポートされておらず
# （0.30.9 が 0.30 系の最終リリース）、自前で持つしかない。
#
# 削除手順: Decidim 0.31.1 以上に上げたら、このファイルとスペックごと消す。
#
# 消し忘れると prepend が黙って勝つ。0.31 以降の copy_meeting! は
# reminder_enabled / send_reminders_before_hours / reminder_message_custom_content の
# 引き渡しとインライン画像処理が増えているため、このコピーが残っていると
# 複製されたミーティングからそれらが抜け落ちる。例外は出ずスペックも通ってしまうので、
# 0.30 系以外では起動時に落として気付けるようにしておく。
if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]
  raise "meeting_copy_taxonomies_override.rb and related specs should be removed in 0.31.x (decidim/decidim#15736)"
end

Rails.application.config.to_prepare do
  module DecidimCfjMeetingCopyTaxonomiesPatch
    private

    # Decidim::Meetings::Admin::CopyMeeting#copy_meeting! (v0.30.9) のコピーに、
    # `taxonomies:` -> `taxonomizations:` の変更を入れたもの。
    # Decidim を上げる際は本家の実装と差分が出ていないか確認すること。
    def copy_meeting!
      parsed_title = Decidim::ContentProcessor.parse_with_processor(:hashtag, form.title, current_organization: meeting.organization).rewrite
      parsed_description = Decidim::ContentProcessor.parse_with_processor(:hashtag, form.description, current_organization: meeting.organization).rewrite

      @copied_meeting = Decidim.traceability.create!(
        Decidim::Meetings::Meeting,
        form.current_user,
        taxonomizations: form.taxonomizations,
        title: parsed_title,
        description: parsed_description,
        end_time: form.end_time,
        start_time: form.start_time,
        address: form.address,
        latitude: form.latitude,
        longitude: form.longitude,
        location: form.location,
        location_hints: form.location_hints,
        component: meeting.component,
        private_meeting: form.private_meeting,
        transparent: form.transparent,
        author: form.current_organization,
        questionnaire: form.questionnaire,
        online_meeting_url: form.online_meeting_url,
        type_of_meeting: form.type_of_meeting,
        iframe_embed_type: form.iframe_embed_type,
        iframe_access_level: form.iframe_access_level,
        comments_enabled: form.comments_enabled,
        comments_start_time: form.comments_start_time,
        comments_end_time: form.comments_end_time,
        registration_type: form.registration_type,
        registration_url: form.registration_url,
        **fields_from_meeting
      )
    end
  end

  Decidim::Meetings::Admin::CopyMeeting.prepend(DecidimCfjMeetingCopyTaxonomiesPatch)
end
