local t = require("./types")
local string = require("./string")
local number = require("./f64")
local enumItem = require("./enumItem")
local array = require("./array")
local bool = require("./bool")

local enumArr = array(enumItem)

local catalogSearchParams: t.Converter<CatalogSearchParams> = {}

function catalogSearchParams.read()
    local params = {
        SearchKeyword = string.read(),
        MinPrice = number.read(),
        MaxPrice = number.read(),
        SortType = enumItem.read(Enum.CatalogSortType),
        SortAggregation = enumItem.read(Enum.CatalogSortAggregation),
        CategoryFilter = enumItem.read(Enum.CatalogCategoryFilter),
        SalesTypeFilter = enumItem.read(Enum.SalesTypeFilter),
        BundleTypes = enumArr.read(Enum.BundleType),
        AssetTypes = enumArr.read(Enum.AssetType),
        IncludeOffSale = bool.read(),
        CreatorName = string.read(),
        CreatorType = enumItem.read(Enum.CreatorType),
        CreatorId = number.read(),
        Limit = number.read()
    }
    
    local searchParams = CatalogSearchParams.new()
    for k, v in params do
        searchParams[k] = v
    end

    return searchParams
end

function catalogSearchParams.write(v: CatalogSearchParams)
    string.write(v.SearchKeyword)
    number.write(v.MinPrice)
    number.write(v.MaxPrice)
    enumItem.write(v.SortType)
    enumItem.write(v.SortAggregation)
    enumItem.write(v.CategoryFilter)
    enumItem.write(v.SalesTypeFilter)
    enumArr.write(v.BundleTypes)
    enumArr.write(v.AssetTypes)
    bool.write(v.IncludeOffSale)
    string.write(v.CreatorName)
    enumItem.write(v.CreatorType)
    number.write(v.CreatorId)
    number.write(v.Limit)

    return
end

function catalogSearchParams.getLengthOf(v: CatalogSearchParams)
    return string.getLengthOf(v.SearchKeyword) +
        number.getLengthOf(v.MinPrice) +
        number.getLengthOf(v.MaxPrice) +
        enumItem.getLengthOf(v.SortType) +
        enumItem.getLengthOf(v.SortAggregation) +
        enumItem.getLengthOf(v.CategoryFilter) +
        enumItem.getLengthOf(v.SalesTypeFilter) +
        enumArr.getLengthOf(v.BundleTypes) +
        enumArr.getLengthOf(v.AssetTypes) +
        bool.getLengthOf(v.IncludeOffSale) +
        string.getLengthOf(v.CreatorName) +
        enumItem.getLengthOf(v.CreatorType) +
        number.getLengthOf(v.CreatorId) +
        number.getLengthOf(v.Limit)
end

return catalogSearchParams