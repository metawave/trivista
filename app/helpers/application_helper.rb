module ApplicationHelper
  ICONS = {
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/>',
    group: '<circle cx="9" cy="8" r="3.5"/><circle cx="17" cy="9" r="2.5"/><path d="M2.5 20c.8-3.5 3.3-5.5 6.5-5.5s5.7 2 6.5 5.5"/><path d="M16 14.5c2.6 0 4.6 1.6 5.3 4.5"/>',
    public: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c2.5 2.5 3.5 5.5 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9s1-6.5 3.5-9z"/>',
    repo: '<path d="M5 4h11l3 3v13H5z"/><path d="M9 9h6"/><path d="M9 13h6"/>',
    branch: '<circle cx="6" cy="5" r="2.5"/><circle cx="6" cy="19" r="2.5"/><circle cx="18" cy="7" r="2.5"/><path d="M6 7.5v9"/><path d="M18 9.5c0 4-6 3-11.5 7"/>',
    settings: '<path d="M4 6h10"/><path d="M18 6h2"/><circle cx="16" cy="6" r="2"/><path d="M4 12h2"/><path d="M10 12h10"/><circle cx="8" cy="12" r="2"/><path d="M4 18h12"/><circle cx="18" cy="18" r="2"/>',
    chevron: '<path d="M6 9l6 6 6-6"/>',
    plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    notice: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9.5"/>',
    alert: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5"/><path d="M12 16.5v.5"/>',
    warning: '<path d="M12 3l9.5 17h-19z"/><path d="M12 10v4"/><path d="M12 17.5v.5"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>',
    sign_in: '<path d="M14 4h5a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-5"/><path d="M10 16l4-4-4-4"/><path d="M14 12H4"/>'
  }.transform_values(&:html_safe).freeze

  def icon(name, size: 16)
    tag.svg(ICONS.fetch(name), class: "icon", width: size, height: size, viewBox: "0 0 24 24", aria: { hidden: true })
  end

  def logo(size: 24, background: "#2a2f37")
    tag.svg(width: size, height: size, viewBox: "0 0 28 28", aria: { hidden: true }) do
      safe_join([
        tag.rect(width: 28, height: 28, rx: 6, fill: background),
        tag.rect(x: 6, y: 7, width: 16, height: 3, rx: 1, fill: "#d0362c"),
        tag.rect(x: 6, y: 12.5, width: 12, height: 3, rx: 1, fill: "#e8821e"),
        tag.rect(x: 6, y: 18, width: 7, height: 3, rx: 1, fill: "#f0c94a")
      ])
    end
  end

  def copy_button(text, label:)
    tag.button(icon(:copy, size: 13), type: "button", class: "btn btn--icon", aria: { label: },
      data: { controller: "clipboard", clipboard_text_value: text, action: "clipboard#copy" })
  end

  def nav_link(name, path, active:)
    link_to name, path, aria: { current: ("page" if active) }
  end

  def visibility_label(project)
    case project.visibility
    when "user" then with_icon(:user, "Only owner")
    when "group" then with_icon(:group, "Group #{project.visibility_group}")
    else with_icon(:public, "All signed-in users")
    end
  end

  def owner_label(owner)
    with_icon(owner.user? ? :user : :group, owner.display_name)
  end

  def with_icon(name, text)
    tag.span(icon(name, size: 14) + text, class: "with-icon")
  end
end
