require "youtu_ocr/version"
require 'rest_client'
require 'json'
require 'youtu_ocr/access_token'

module YoutuOcr

  OCR_URL = {
    id_card: "#{@end_point}idcardocr",
    id_card_back: "#{@end_point}idcardocr",
    bank_card: "#{@end_point}creditcardocr",
    driving_license: "#{@end_point}driverlicenseocr",
    driving_license_vice: "#{@end_point}generalocr",
    vehicle_license: "#{@end_point}driverlicenseocr",
    business_license: "#{@end_point}bizlicenseocr"
  }.freeze

  # 图像识别
  # @param type 图片类型
  # @param image 图片的Base64位字符串
  def ocr(type, image)
    type = type.to_sym
    config = send(type)
    body_params = {
      app_id: @app_id,
      image: image
    }.merge(config[:params])
    url = OCR_URL[type]
    response = RestClient.post(url, body_params.to_json, Authorization: access_token)
    object = JSON.parse(response)
    error_code, error_msg = object.values_at("errorcode", "errormsg")
    result = error_code == 0 ? common_mapping(object, config[:mapping]) : {}

    {
      error_code: error_code,
      error_msg: error_msg,
      result: result
    }
  end

  private

  def common_mapping(object, mapping)
    replace, append = mapping[:__replace], mapping[:__append]
    if replace
      new_object = replace.call(object)
    else
      item_array = object["items"].map { |item| item.values_at("item", "itemstring") }
      new_object = item_array.to_h
    end
    new_object = new_object.transform_keys { |key| mapping.key(key) }
    new_object = append.call(new_object) if append.present?
    new_object.slice(*mapping.keys)
  end

  def id_card
    {
      # card_type: 身份证图片类型，0-正面，1-反面
      params: {card_type: 0},
      mapping: {
        name: "name",
        sex: "sex",
        nation: "nation",
        birthday: "birth",     # 1999/9/20
        address: "address",
        id_number: "id",
        __replace: ->(result) do
          result.slice(*%w(name sex nation birth address id))
        end
      }
    }
  end

  def id_card_back
    {
      # card_type: 身份证图片类型，0-正面，1-反面
      params: {card_type: 1},
      mapping: {
        authority: "authority",
        valid_date: "valid_date",
        id_begin_at: "id_begin_at",
        id_end_at: "id_end_at",
        __replace: ->(result) do
          valid_dates = result['valid_date'].split('-')
          result['id_begin_at'], result['id_end_at'] = valid_dates
          if result['id_begin_at'].to_date.present? && result['id_end_at'].blank?
            result['id_end_at'] = (result['id_begin_at'].to_date + 50.years).to_s
          end
          result.slice(*%w(authority id_begin_at id_end_at))
        end
      }
    }
  end

  def bank_card
    {
      params: {},
      mapping: {
        bank_card_number: "卡号",
        bank_name: "银行信息",
        card_name: "卡名字",
        expire_date: "有效期",
        bank_card_type: "卡类型"
      }
    }
  end

  def driving_license
    {
      params: {type: 1},
      mapping: {
        driver_license: "证号",
        id_number: "证号",
        name: "姓名",
        sex: "性别",
        nationality: "国籍",
        address: "住址",
        birthday: "出生日期",
        driving_license_first_get_at: "领证日期",
        driving_class: "准驾车型",
        driver_license_level: "准驾车型",
        driving_license_start_at: "起始日期",
        driver_license_end_at: "有效日期",
        __append: ->(result) do
          result[:id_number] = result[:driver_license]
          result[:driver_license_level] = result[:driving_class]
          result
        end
      }
    }
  end

  def driving_license_vice
    {
      params: {},
      mapping: {
        archives_number: 'archives_number',
        __replace: ->(result) do
          items = result['items'].map {|item| item['itemstring']}
          ocr_flag, archives_number = items.any? {|item| item.include?('档案编号')} || items.any? {|item| item.include?('驾驶证副页')}, ''
          items.each_with_index do |item, index|
            if item.include?('档案编号')
              arc_item = item.gsub(/\D/, '').eql?('') ? items[index + 1].to_s : item
              archives_number = arc_item.gsub(/\D/, '')
            end
          end
          ocr_flag ? {'archives_number'=> archives_number} : {}
        end
      }
    }
  end

  def vehicle_license
    {
      params: {type: 0},
      mapping: {
        plate_no: "车牌号码",
        vehicle_type: "车辆类型",
        owner: "所有人",
        address: "住址",
        use_character: "使用性质",
        model: "品牌型号",
        vin: "识别代码",
        engine_no: "发动机号",
        register_date: "注册日期",  # YYYY-MM-DD
        issue_date: "发证日期"
      }
    }
  end

  def business_license
    {
      params: {},
      mapping: {
        id_number: "注册号",
        legal_person: "法定代表人",
        unit_name: "公司名称",
        address: "地址",
        expire_date: "营业期限"     # 二0一四年九月四日至长期
      }
    }
  end
end
