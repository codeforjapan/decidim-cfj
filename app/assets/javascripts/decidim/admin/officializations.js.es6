$(() => {
  const $modal = $("#show-user-modal");

  if ($modal.length === 0) {
    return
  }

  const $button = $("[data-open=user_extension]", $modal);
  const $fullName = $("#user_full_name2", $modal);
  const $keyList = ["real_name", "address", "birth_year", "gender", "occupation"];

  $("[data-toggle=show-user-modal]").on("click", (event) => {
    event.preventDefault()

    $button.show()
    $button.attr("data-open-url", event.currentTarget.href)
    $fullName.text($(event.currentTarget).data("full-name"))
    $keyList.forEach((key) => {
      let $user_extension_item = $("#user_extension_" + key, $modal);
      $user_extension_item.html("")
    })
  })
})
