# ViewComponent Subtemplates

[![Gem Version](https://badge.fury.io/rb/view_component_subtemplates.svg)](https://badge.fury.io/rb/view_component_subtemplates)
[![Build Status](https://github.com/bukhr/view_component_subtemplates/workflows/CI/badge.svg)](https://github.com/bukhr/view_component_subtemplates/actions)

Adds support for **sub-templates with typed arguments** to [ViewComponent](https://viewcomponent.org/), enabling modular, reusable component architectures.

## Features

✅ **Template Arguments** - Define typed arguments for sub-templates  
✅ **Automatic Detection** - Sub-templates discovered in component sidecar directories  
✅ **Dynamic Methods** - `call_[name]` helper methods generated automatically  
✅ **ViewComponent Integration** - Seamless integration with existing ViewComponent workflow  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'view_component_subtemplates'
```

And then execute:

```bash
bundle install
```

## Quick Start

### 1. Define a component

```ruby
# app/components/table_component.rb
class TableComponent < ViewComponent::Base
  def initialize(users:, title:)
    @users = users
    @title = title
  end
end
```

### 2. Create your templates

```erb
<!-- app/components/table_component.html.erb -->
<div class="table-container">
  <%= call_header(title: @title, sortable: true) %>
  
  <tbody>
    <% @users.each_with_index do |user, index| %>
      <%= call_row(model: user, highlight: index.even?) %>
    <% end %>
  </tbody>
  
  <%= call_footer(total_count: @users.count) %>
</div>
```

### 3. File structure

```
app/components/
├── table_component.rb
├── table_component.html.erb
└── table_component/
    ├── header.html.erb
    ├── row.html.erb
    └── footer.html.erb
```

### 4. Sub-template files

```erb
<!-- app/components/table_component/header.html.erb -->
<%# locals: (title:, sortable:) -%>
<thead class="<%= 'sortable' if sortable %>">
  <tr>
    <th><%= title %></th>
    <th>Actions</th>
  </tr>
</thead>
```

```erb
<!-- app/components/table_component/row.html.erb -->
<%# locals: (model:, highlight:) -%>
<tr class="<%= 'highlighted' if highlight %>">
  <td><%= model.name %></td>
  <td><%= model.email %></td>
</tr>
```

```erb
<!-- app/components/table_component/footer.html.erb -->
<%# locals: (total_count:) -%>
<tfoot>
  <tr>
    <td colspan="2">Total: <%= total_count %> users</td>
  </tr>
</tfoot>
```

### 5. Use in your views

```erb
<%= render TableComponent.new(users: @users, title: "User List") %>
```

## Rendering a subtemplate on its own

Sometimes you need to render just one subtemplate, outside the component's main
template. A common case is a controller action that responds to an AJAX request
with only an updated fragment.

Call `render_subtemplate_in` on a component instance, passing the current view
context. The subtemplate **must not declare locals**: any per-render data is
passed through the component's constructor, so the call site stays free of an
untyped `**locals` boundary.

```ruby
class UsersController < ApplicationController
  def row
    component = RowComponent.new(user: User.find(params[:id]), highlight: false)

    render html: component.render_subtemplate_in(view_context, :row), layout: false
  end
end
```

```erb
<%# app/components/row_component/row.html.erb -- no `locals:` line %>
<tr class="<%= 'highlighted' if @highlight %>"><td><%= @user.name %></td></tr>
```

`render_subtemplate_in(view_context, name)` renders the named subtemplate and
returns its HTML as an html_safe string, without rendering the component's main
template. It is the subtemplate-level counterpart of ViewComponent's `render_in`:
`render_in(view_context)` is the external entry point for the main template
(internally `call`), and `render_subtemplate_in` is the external entry point for
a single subtemplate (internally `call_<name>`).

`render_subtemplate_in` raises a clear error if the named subtemplate does not
exist, or if it declares locals (pass that data through the component's
constructor instead).

**The no-locals rule applies only to standalone rendering.** Inside a component's
templates, `call_<name>` keeps taking locals exactly as shown in the Quick Start;
`render_subtemplate_in` is the only path that requires a no-locals subtemplate.

## Requirements

- Ruby >= 3.1.0
- Rails >= 7.0.0
- ViewComponent >= 4.2.0

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

```bash
bundle install
bundle exec rake test
```

