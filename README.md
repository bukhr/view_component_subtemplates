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

