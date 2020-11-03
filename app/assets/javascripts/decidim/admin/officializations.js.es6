// from decidim/decidim-admin/app/assets/javascripts/decidim/admin/officializations.js.es6
$(() => {
  const $modal = $("#show-email-modal");

  if ($modal.length === 0) {
    return
  }

  const $button = $("[data-open=user_email]", $modal);
  const $email = $("#user_email", $modal);
  const $fullName = $("#user_full_name", $modal);

  $("[data-toggle=show-email-modal]").on("click", (event) => {
    event.preventDefault()

    $button.show()
    $button.attr("data-open-url", event.currentTarget.href)
    $fullName.text($(event.currentTarget).data("full-name"))
    $email.html("")
  })
})

// added decidim-cfj
$(() => {
  const $modal = $("#show-user-modal");

  if ($modal.length === 0) {
    return
  }

  const $button = $("[data-open=user_extension]", $modal);
  const $userExtension = $("#user_extension", $modal);
  const $fullName = $("#user_full_name2", $modal);

  $("[data-toggle=show-user-modal]").on("click", (event) => {
    event.preventDefault()

    $button.show()
    $button.attr("data-open-url", event.currentTarget.href)
    $fullName.text($(event.currentTarget).data("full-name"))
    $userExtension.html("")
  })
})
