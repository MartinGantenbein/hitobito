# encoding: utf-8

#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Group::Merger < Struct.new(:group1, :group2, :new_group_name)

  attr_reader :new_group, :errors

  def merge!
    raise('Cant merge these Groups') unless group2_valid?

    ::Group.transaction do
      if create_new_group
        update_events
        copy_roles
        move_children(group1)
        move_children(group2)
        delete_old_groups
      end
    end
  end

  def group2_valid?
    (group1.class == group2.class && group1.parent_id == group2.parent_id)
  end

  private

  def create_new_group
    new_group = group1.class.new
    new_group.name = new_group_name
    new_group.parent_id = group1.parent_id
    success = new_group.save
    if success
      new_group.reload
      @new_group = new_group
    else
      @errors = new_group.errors.full_messages
    end
    success
  end

  def update_events
    events = (group1.events + group2.events).uniq
    events.each do |event|
      event.groups << new_group
      event.save!
    end
  end

  def move_children(group)
    children = group1.children + group2.children
    children.each do |child|
      child.parent_id = new_group.id
      child.save!
      child.update_attribute(:layer_group_id, child.layer_group.id)
    end
    group.children.update_all(parent_id: new_group.id)
  end

  def copy_roles
    roles = group1.roles + group2.roles
    roles.each do |role|
      new_role = role.dup
      new_role.group_id = new_group.id
      new_role.save!
    end
  end

  def delete_old_groups
    group1.destroy
    group2.destroy
  end

end
