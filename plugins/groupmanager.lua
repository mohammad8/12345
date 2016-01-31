-- data saved to data/moderation.json
do

local function export_chat_link_cb(extra, success, result)
local msg = extra.msg
local data = extra.data
if success == 0 then
return send_large_msg(get_receiver(msg), 'اشکال در گرفتن لینک گروه\nمطمئن شوید مدیر گروه هستید')
end
data[tostring(msg.to.id)]['link'] = result
save_data(_config.moderation.data, data)
return send_large_msg(get_receiver(msg),'لینک جدید گروه: '..msg.to.title..':\n'..result)
end

local function set_group_photo(msg, success, result)
local data = load_data(config.moderation.data)
if success then
local file = 'data/photos/chat_photo'..msg.to.id..'.jpg'
print('File downloaded to:', result)
os.rename(result, file)
print('File moved to:', file)
chat_set_photo (get_receiver(msg), file, ok_cb, false)
data[tostring(msg.to.id)]['settings']['set_photo'] = file
save_data(_config.moderation.data, data)
data[tostring(msg.to.id)]['settings']['lock_photo'] = 'yes'
save_data(_config.moderation.data, data)
send_large_msg(get_receiver(msg), 'Photo saved!', ok_cb, false)
else
print('Error downloading: '..msg.id)
send_large_msg(get_receiver(msg), 'خطا, لطفا دوباره تلاش کنید', ok_cb, false)
end
end

local function get_description(msg, data)
local about = data[tostring(msg.to.id)]['description']
if not about then
return 'توضیحی وجود ندارد'
end
return string.gsub(msg.to.print_name, '_', ' ')..':\n\n'..about
end

-- media handler. needed by group_photo_lock
local function pre_process(msg)
if not msg.text and msg.media then
msg.text = '['..msg.media.type..']'
end
return msg
end

function run(msg, matches)

if is_chat_msg(msg) then
  local data = load_data(_config.moderation.data)

       -- create a group
  if matches[1] == 'mkgroup' and matches[2] and is_mod(msg.from.id, msg.to.id) then
    create_group_chat (msg.from.print_name, matches[2], ok_cb, false)
      return 'گروه '..string.gsub(matches[2], '_', ' ')..' ساخته شد.'
  -- add a group to be moderated
  elseif matches[1] == 'addgroup' and is_admin(msg.from.id, msg.to.id) then
    if data[tostring(msg.to.id)] then
      return 'Group is already added.'
    end
    -- create data array in moderation.json
    data[tostring(msg.to.id)] = {
      moderators ={},
      settings = {
        set_name = string.gsub(msg.to.print_name, '_', ' '),
        lock_bots = 'no',
        lock_name = 'yes',
        lock_photo = 'no',
        lock_member = 'no',
        anti_flood = 'ban',
        welcome = 'group',
        sticker = 'ok',
        }
      }
    save_data(_config.moderation.data, data)
    return 'گروه ادد شده است'
  -- remove group from moderation
  elseif matches[1] == 'remgroup' and is_admin(msg.from.id, msg.to.id) then
    if not data[tostring(msg.to.id)] then
      return 'گروه ادد نشده است'
    end
    data[tostring(msg.to.id)] = nil
    save_data(_config.moderation.data, data)
    return 'گروه پاک شد'
  end
  if msg.media and is_chat_msg(msg) and is_mod(msg.from.id, msg.to.id) then
    if msg.media.type == 'photo' and data[tostring(msg.to.id)] then
      if data[tostring(msg.to.id)]['settings']['set_photo'] == 'waiting' then
        load_photo(msg.id, set_group_photo, msg)
      end
    end
  end

  if data[tostring(msg.to.id)] then

    local settings = data[tostring(msg.to.id)]['settings']

    if matches[1] == 'setabout' and matches[2] and is_mod(msg.from.id, msg.to.id) then
        data[tostring(msg.to.id)]['description'] = matches[2]
        save_data(_config.moderation.data, data)
        return 'توضیحات گروه تنظیم شد:\n'..matches[2]
    elseif matches[1] == 'about' then
      return get_description(msg, data)
    elseif matches[1] == 'setrules' and is_mod(msg.from.id, msg.to.id) then
        data[tostring(msg.to.id)]['rules'] = matches[2]
        save_data(_config.moderation.data, data)
        return 'قوانین گروه تنظیم شد:\n'..matches[2]
    elseif matches[1] == 'rules' then
      if not data[tostring(msg.to.id)]['rules'] then
        return 'قانونی وجود ندارد'
        end
      local rules = data[tostring(msg.to.id)]['rules']
      local rules = string.gsub(msg.to.print_name, '_', ' ')..' rules:\n\n'..rules
      return rules
    -- group link {get|set}
    elseif matches[1] == 'link' then
      if matches[2] == 'get' then
        if data[tostring(msg.to.id)]['link'] then
          local about = get_description(msg, data)
          local link = data[tostring(msg.to.id)]['link']
          return about..'\n\n'..link
        else
          return 'لینک گروه یافت نشد.\nبا ذستور !link set لینک گروه را ایجاد کنید '
        end
      elseif matches[2] == 'set' and is_mod(msg.from.id, msg.to.id) then
        msgr = export_chat_link(get_receiver(msg), export_chat_link_cb, {data=data, msg=msg})
      end
      elseif matches[1] == 'group' then
      -- lock {bot|name|member|photo|sticker}
      if matches[2] == 'lock' then
        if matches[3] == 'bot' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_bots == 'yes' then
            return 'آنتی ربات فعال است.'
            else
            settings.lock_bots = 'yes'
            save_data(_config.moderation.data, data)
            return 'آنتی ربات فعال شد'
            end
        elseif matches[3] == 'name' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_name == 'yes' then
            return 'عنوان گروه قفل میباشد'
            else
            settings.lock_name = 'yes'
            save_data(_config.moderation.data, data)
            settings.set_name = string.gsub(msg.to.print_name, '_', ' ')
            save_data(_config.moderation.data, data)
              return 'عنوان گروه قفل شد'
            end
        elseif matches[3] == 'member' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_member == 'yes' then
            return 'ورود عضو جدید به گروه قفل میباشد'
            else
            settings.lock_member = 'yes'
            save_data(_config.moderation.data, data)
            end
            return 'ورود عضو جدید به گروه قفل شد'
        elseif matches[3] == 'photo' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_photo == 'yes' then
            return 'عکس گروه قفل میباشد'
            else
            settings.set_photo = 'waiting'
            save_data(_config.moderation.data, data)
            end
          return 'لطفا عکس جدید را ارسال کنید'
        end
      -- unlock {bot|name|member|photo|sticker}
          elseif matches[2] == 'unlock' then
        if matches[3] == 'bot' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_bots == 'no' then
            return 'ربات اجازه ورود به گروه را دارد+'
            else
            settings.lock_bots = 'no'
            save_data(_config.moderation.data, data)
            return 'آنتی ربات غیرفعال است'
            end
        elseif matches[3] == 'name' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_name == 'no' then
            return 'درحال حاضر عنوان گروه باز میباشد'
            else
            settings.lock_name = 'no'
            save_data(_config.moderation.data, data)
            return 'عنوان گروه آزاد شد'
            end
        elseif matches[3] == 'member' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_member == 'no' then
            return 'ورود عضو جدید آزاد میباشد'
            else
            settings.lock_member = 'no'
            save_data(_config.moderation.data, data)
            return 'ورود عضو جدید آزاد شد'
            end
        elseif matches[3] == 'photo' and is_mod(msg.from.id, msg.to.id) then
            if settings.lock_photo == 'no' then
            return 'عکس گروه آزاد است'
            else
            settings.lock_photo = 'no'
            save_data(_config.moderation.data, data)
            return 'عکس گروه آزاد شد'
            end
        end
      -- view group settings
      elseif matches[2] == 'settings' and is_mod(msg.from.id, msg.to.id) then
        if settings.lock_bots == 'yes' then
          lock_bots_state = '🔒'
        elseif settings.lock_bots == 'no' then
          lock_bots_state = '🔓'
        end
        if settings.lock_name == 'yes' then
          lock_name_state = '🔒'
        elseif settings.lock_name == 'no' then
          lock_name_state = '🔓'
        end
        if settings.lock_photo == 'yes' then
          lock_photo_state = '🔒'
        elseif settings.lock_photo == 'no' then
          lock_photo_state = '🔓'
        end
        if settings.lock_member == 'yes' then
          lock_member_state = '🔒'
        elseif settings.lock_member == 'no' then
          lock_member_state = '🔓'
        end
        if settings.anti_flood ~= 'no' then
          antispam_state = '🔒'
        elseif settings.anti_flood == 'no' then
          antispam_state = '🔓'
        end
        if settings.welcome ~= 'no' then
          greeting_state = '🔒'
        elseif settings.welcome == 'no' then
          greeting_state = '🔓'
        end
        if settings.sticker ~= 'ok' then
          sticker_state = '🔒'
        elseif settings.sticker == 'ok' then
          sticker_state = '🔓'
        end
        local text = 'تنظیمات گروه:\n'
              ..'\n'..lock_bots_state..' آنتی ربات : '..settings.lock_bots
              ..'\n'..lock_name_state..' قفل عنوان گروه : '..settings.lock_name
              ..'\n'..lock_photo_state..'  قفل عکس گروه  : '..settings.lock_photo
              ..'\n'..lock_member_state..' قفل ورود عضو جدید    : '..settings.lock_member
              ..'\n'..antispam_state..' آنتی اسپم : '..settings.anti_flood
              ..'\n'..sticker_state..' آنتی استیکر : '..settings.sticker
              ..'\n'..greeting_state..' خوش آمد گویی : '..settings.welcome
        return text
          end
    elseif matches[1] == 'sticker' then
      if matches[2] == 'warn' then
        if settings.sticker ~= 'warn' then
          settings.sticker = 'warn'
          save_data(_config.moderation.data, data)
        end
        return 'ارسال استیکر مجاز نیست.\n'
               ..'این یک اخطار است, اگر تکرار شود کیک خواهی شد'
      elseif matches[2] == 'kick' then
        if settings.sticker ~= 'kick' then
          settings.sticker = 'kick'
          save_data(_config.moderation.data, data)
        end
        return 'ارسال استیکر مجاز نیست.\nشما از  گروه اخراج میشوید'
      elseif matches[2] == 'ok' then
        if settings.sticker == 'ok' then
          return 'آنتی استیکر فعال نیست'
        else
          settings.sticker = 'ok'
          save_data(_config.moderation.data, data)
          return 'آنتی استیکر غیر فعال شد'
        end
      end
    -- if group name is renamed
    elseif matches[1] == 'chat_rename' then
      if not msg.service then
        return 'Are you trying to troll me?'
      end
      if settings.lock_name == 'yes' then
        if settings.set_name ~= tostring(msg.to.print_name) then
          rename_chat(get_receiver(msg), settings.set_name, ok_cb, false)
        end
      elseif settings.lock_name == 'no' then
        return nil
      end
        -- set group name
        elseif matches[1] == 'setname' and is_mod(msg.from.id, msg.to.id) then
      settings.set_name = string.gsub(matches[2], '_', ' ')
      save_data(_config.moderation.data, data)
      rename_chat(get_receiver(msg), settings.set_name, ok_cb, false)
        -- set group photo
        elseif matches[1] == 'setphoto' and is_mod(msg.from.id, msg.to.id) then
      settings.set_photo = 'waiting'
      save_data(_config.moderation.data, data)
      return 'لطفا عکس جدید را ارسال کنید'
    -- if a user is added to group
        elseif matches[1] == 'chat_add_user' then
      if not msg.service then
        return 'Are you trying to troll me?'
      end
      local user = 'user#id'..msg.action.user.id
      if settings.lock_member == 'yes' then
        chat_del_user(get_receiver(msg), user, ok_cb, true)
      -- no APIs bot are allowed to enter chat group, except invited by mods.
      elseif settings.lock_bots == 'yes' and msg.action.user.flags == 4352 and not is_mod(msg.from.id, msg.to.id) then
        chat_del_user(get_receiver(msg), user, ok_cb, true)
      elseif settings.lock_bots == 'no' or settings.lock_member == 'no' then
        return nil
      end
    -- if sticker is sent
    elseif msg.media and msg.media.caption == 'sticker.webp' and not is_sudo(msg.from.id) then
      local user_id = msg.from.id
      local chat_id = msg.to.id
      local sticker_hash = 'mer_sticker:'..chat_id..':'..user_id
      local is_sticker_offender = redis:get(sticker_hash)
      if settings.sticker == 'warn' then
        if is_sticker_offender then
          chat_del_user(get_receiver(msg), 'user#id'..user_id, ok_cb, true)
          redis:del(sticker_hash)
          return 'استیکر مجاز نیست.شما یک اخطار در این گروه دارید'
        elseif not is_sticker_offender then
          redis:set(sticker_hash, true)
          return 'استیکر در این گروه مجاز نیست!\nدر صورت تکرار حذف می شوید'
        end
      elseif settings.sticker == 'kick' then
        chat_del_user(get_receiver(msg), 'user#id'..user_id, ok_cb, true)
        return 'استیکر در این گروه مجاز نیست'
      elseif settings.sticker == 'ok' then
        return nil
      end
    -- if group photo is deleted
        elseif matches[1] == 'chat_delete_photo' then
      if not msg.service then
        return 'Are you trying to troll me?'
      end
      if settings.lock_photo == 'yes' then
        chat_set_photo (get_receiver(msg), settings.set_photo, ok_cb, false)
      elseif settings.lock_photo == 'no' then
        return nil
      end
        -- if group photo is changed
        elseif matches[1] == 'chat_change_photo' and msg.from.id ~= 0 then
      if not msg.service then
        return 'Are you trying to troll me?'
      end
      if settings.lock_photo == 'yes' then
        chat_set_photo (get_receiver(msg), settings.set_photo, ok_cb, false)
      elseif settings.lock_photo == 'no' then
        return nil
      end
    end
  end
else
  print '>>> This is not a chat group.'
end
end

return {
description = 'Plugin to manage group chat.',
usage = {
admin = {
'!cg : Make/create a new group.',
'!add : Add group to moderation list.',
'!rem : Remove group from moderation list.'
},
moderator = {
'!group bot : {Dis}allow APIs bots.',
'!group member : Lock/unقفل/بازکردن ورود عضو جدید .',
'!group name : Lock/un قفل/بازکردن عنوان گروه.',
'!group photo : Lock/un قفل/بازکردن عکس گروه .',
'!group settings : مشاهده تنظیمات گروه.',
'!link : ساخت/تعویض لینک گروه.',
'!setabout : تنظیم توضیحات گروه',
'!setname : تنظیم نام جدید.',
'!setphoto : تنظیم عکس گروه.',
'!setrules : تنظیم قوانین.',
'!sticker warn : آنتی استیکر,بار اول به فرد خطاکار اخطار داده خواهد شد',
'!sticker kick : آنتی استیکر, فردخطاکار کیک خواهد شد',
'!sticker ok : آزاد کردن استیکر در گروه'
},
user = {
'!about : مشاهده توضیحات گروه',
'!rules : مشاهده قوانین گروه',
'!link : گرفتن لینک گروه'
},
},
patterns = {
'^!(about)$',
'^!(addgroup)$',
'%[(audio)%]',
'%[(document)%]',
'^!(group) (lock) (.)$',
'^!(group) (settings)$',
'^!(group) (unlock) (.)$',
'^!(link) (.)$',
'^!(mkgroup) (.)$',
'%[(photo)%]',
'^!(remgroup)$',
'^!(rules)$',
'^!(setabout) (.)$',
'^!(setname) (.)$',
'^!(setphoto)$',
'^!(setrules) (.)$',
'^!(sticker) (.)$',
'^!!tgservice (.+)$',
'%[(video)%]'
},
run = run,
pre_process = pre_process
}

end
