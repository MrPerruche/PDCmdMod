#include <stdio.h>
#include <string>
#include <Mod/CppUserModBase.hpp>
#include <DynamicOutput/Output.hpp>
#include <LuaMadeSimple/LuaMadeSimple.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/UClass.hpp>
#include <Unreal/FString.hpp>
#include <Unreal/NameTypes.hpp>
#include <Unreal/Property/FTextProperty.hpp>
#include <Unreal/FText.hpp>

using namespace RC;
using namespace RC::Unreal;

// ============================================================
// PDCmdMod: C++ bridge mod for Pacific Drive UE4SS Lua mods.
//
// Exposes the following Lua globals:
//
//   PDGetFText(assetPath, propertyName) -> string|nil
//     Loads an asset by full path, reads an FText property,
//     and returns the display string as a plain Lua string.
//     Returns nil if the asset or property doesn't exist.
//
// Usage from Lua:
//   local title = PDGetFText(
//     "/Game/Gameplay/Inventory/Items/Resources/Basic/RawLead/IA_Resource_Raw_Lead.IA_Resource_Raw_Lead",
//     "Title"
//   )
// ============================================================

class PDCmdMod : public RC::CppUserModBase
{
public:
    PDCmdMod()
    {
        ModVersion = STR("0.1");
        ModName = STR("PDCmdMod");
        ModAuthors = STR("Perru");
        ModDescription = STR("Pacific Drive C++/Lua bridge mod");
    }

    ~PDCmdMod() override {}

    auto on_program_start() -> void override {}

    auto on_unreal_init() -> void override
    {
        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Unreal initialized.\n"));
    }

    // Fires for every Lua mod that starts
    auto on_lua_start(
        StringViewType mod_name,
        LuaMadeSimple::Lua& lua,
        LuaMadeSimple::Lua& main_lua,
        LuaMadeSimple::Lua& async_lua,
        LuaMadeSimple::Lua* hook_lua) -> void override
    {
        RegisterBridgeFunctions(lua);
        RegisterBridgeFunctions(main_lua);
    }

    // Fires only for our own Lua mod (PDCmdMod/Scripts/main.lua)
    auto on_lua_start(
        LuaMadeSimple::Lua& lua,
        LuaMadeSimple::Lua& main_lua,
        LuaMadeSimple::Lua& async_lua,
        LuaMadeSimple::Lua* hook_lua) -> void override
    {
        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Registering bridge for own Lua mod.\n"));
        RegisterBridgeFunctions(lua);
        RegisterBridgeFunctions(main_lua);
    }

private:

    auto RegisterBridgeFunctions(LuaMadeSimple::Lua& lua) -> void
    {
        static UObject* s_lastCreatedWidget = nullptr;
        // --------------------------------------------------------
        // PDGetFText(assetPath, propertyName) -> string|nil
        //
        // Parameters:
        //   assetPath    - Full Unreal asset path string
        //                  e.g. "/Game/.../IA_Resource_Raw_Lead.IA_Resource_Raw_Lead"
        //   propertyName - FText property name on the asset (e.g. "Title")
        //
        // Returns: string on success, nil on failure
        // --------------------------------------------------------
        lua.register_function("PDGetFText", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                if (lua_gettop(L) < 2)
                {
                    lua_pushnil(L);
                    return 1;
                }

                // Arg 1: asset path as UTF-8 string
                if (!lua_isstring(L, 1))
                {
                    lua_pushnil(L);
                    return 1;
                }
                const char* pathUtf8 = lua_tostring(L, 1);

                // Arg 2: property name as UTF-8 string
                if (!lua_isstring(L, 2))
                {
                    lua_pushnil(L);
                    return 1;
                }
                const char* propUtf8 = lua_tostring(L, 2);

                // Convert UTF-8 strings to wide strings for UE4SS APIs
                std::string pathStr(pathUtf8);
                std::wstring pathWide(pathStr.begin(), pathStr.end());

                std::string propStr(propUtf8);
                std::wstring propWide(propStr.begin(), propStr.end());

                // Load the asset fresh via StaticFindObject
                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, pathWide.c_str());

                if (!obj)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] StaticFindObject returned null for path\n"));
                    lua_pushnil(L);
                    return 1;
                }
                // Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Found object\n"));

                UClass* cls = obj->GetClassPrivate();
                if (!cls)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] GetClassPrivate returned null\n"));
                    lua_pushnil(L);
                    return 1;
                }
                // Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Got class\n"));

                FName propName(propWide.c_str());
                FProperty* prop = cls->FindProperty(propName);
                if (!prop)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] FindProperty returned null\n"));
                    lua_pushnil(L);
                    return 1;
                }
                // Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Found property\n"));

                // Cast to FTextProperty
                FTextProperty* textProp = CastField<FTextProperty>(prop);
                if (!textProp)
                {
                    lua_pushnil(L);
                    return 1;
                }

                // Get pointer to the FText value inside the object
                FText* textValue = textProp->ContainerPtrToValuePtr<FText>(obj);
                if (!textValue)
                {
                    lua_pushnil(L);
                    return 1;
                }

                // Convert FText to string
                // ToString() returns RC::StringType which is std::wstring
                RC::StringType result = textValue->ToString();
                if (result.empty())
                {
                    lua_pushnil(L);
                    return 1;
                }

                // Convert wide string to UTF-8 for Lua
                std::string utf8Str(result.begin(), result.end());
                lua_pushstring(L, utf8Str.c_str());
                return 1;
            });


        lua.register_function("PDEnumerateFunctions", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                if (!lua_isstring(L, 1))
                {
                    lua_pushnil(L);
                    return 1;
                }

                const char* pathUtf8 = lua_tostring(L, 1);
                std::wstring pathWide(pathUtf8, pathUtf8 + strlen(pathUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, pathWide.c_str());

                if (!obj)
                {
                    lua_pushnil(L);
                    return 1;
                }

                UClass* cls = obj->GetClassPrivate();
                if (!cls)
                {
                    lua_pushnil(L);
                    return 1;
                }

                lua_newtable(L);
                int idx = 1;

                for (UFunction* func : cls->ForEachFunction())
                {
                    if (func)
                    {
                        RC::StringType name = func->GetName();
                        std::string utf8name(name.begin(), name.end());
                        lua_pushstring(L, utf8name.c_str());
                        lua_rawseti(L, -2, idx++);
                    }
                }

                return 1;
            });

        lua.register_function("PDCreateWidget", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 3 || !lua_isstring(L, 1) || !lua_isstring(L, 2) || !lua_isstring(L, 3))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* widgetClassPathUtf8 = lua_tostring(L, 1);
                const char* worldContextPathUtf8 = lua_tostring(L, 2);
                const char* playerControllerPathUtf8 = lua_tostring(L, 3);

                std::wstring widgetClassPath(widgetClassPathUtf8, widgetClassPathUtf8 + strlen(widgetClassPathUtf8));
                std::wstring worldContextPath(worldContextPathUtf8, worldContextPathUtf8 + strlen(worldContextPathUtf8));
                std::wstring playerControllerPath(playerControllerPathUtf8, playerControllerPathUtf8 + strlen(playerControllerPathUtf8));

                // Find widget class
                UObject* widgetClass = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, widgetClassPath.c_str(), true);
                if (!widgetClass)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: widget class not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find world context (any live UObject works)
                UObject* worldContext = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, worldContextPath.c_str());
                if (!worldContext)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: world context not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find player controller
                UObject* playerController = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, playerControllerPath.c_str());
                if (!playerController)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: player controller not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find UWidgetBlueprintLibrary CDO
                UObject* wbl = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, STR("/Script/UMG.Default__WidgetBlueprintLibrary"));
                if (!wbl)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: WidgetBlueprintLibrary not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find Create function
                UFunction* createFunc = wbl->GetFunctionByName(STR("Create"));
                if (!createFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: Create function not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Call Create — params: WorldContext, WidgetType (class), OwningPlayer, ReturnValue
                struct CreateParams
                {
                    UObject* WorldContext;
                    UObject* WidgetType;
                    UObject* OwningPlayer;
                    UObject* ReturnValue;
                };
                CreateParams createParams{ worldContext, widgetClass, playerController, nullptr };
                wbl->ProcessEvent(createFunc, &createParams);

                UObject* widget = createParams.ReturnValue;
                if (!widget)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: Create returned null widget\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDCreateWidget: widget created, adding to viewport\n"));

                // Call AddToViewport(0) directly on the widget — params: ZOrder (int32)
                UFunction* addFunc = widget->GetFunctionByName(STR("AddToViewport"));
                if (!addFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateWidget: AddToViewport not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct AddToViewportParams { int32_t ZOrder; };
                AddToViewportParams addParams{ 0 };
                widget->ProcessEvent(addFunc, &addParams);

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDCreateWidget: done\n"));
                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDSetWhiteboardTag", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                if (lua_gettop(L) < 3 || !lua_isstring(L, 1) || !lua_isstring(L, 2) || !lua_isnumber(L, 3))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* wbPathUtf8 = lua_tostring(L, 1);
                const char* tagUtf8 = lua_tostring(L, 2);
                float value = static_cast<float>(lua_tonumber(L, 3));

                std::wstring wbPath(wbPathUtf8, wbPathUtf8 + strlen(wbPathUtf8));
                std::wstring tagStr(tagUtf8, tagUtf8 + strlen(tagUtf8));

                UObject* wb = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, wbPath.c_str());

                if (!wb)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find SetTagFloat UFunction and call it
                UFunction* func = wb->GetFunctionByName(STR("SetTagFloat"));
                if (!func)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct FGameplayTag { FName TagName; };
                FName tagName(tagStr.c_str());
                FGameplayTag tag{ tagName };

                struct SetTagFloatParams { FGameplayTag Tag; float Value; };
                SetTagFloatParams params{ tag, value };
                wb->ProcessEvent(func, &params);

                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDSetWhiteboardTagOnObject", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 3 || !lua_isstring(L, 2) || !lua_isnumber(L, 3))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                // First arg is a UObject passed from Lua
                UObject* wb = nullptr;
                if (lua_isuserdata(L, 1))
                {
                    // UE4SS wraps UObjects as userdata
                    wb = *static_cast<UObject**>(lua_touserdata(L, 1));
                }
                if (!wb)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* tagUtf8 = lua_tostring(L, 2);
                float value = (float)lua_tonumber(L, 3);
                std::wstring tagStr(tagUtf8, tagUtf8 + strlen(tagUtf8));

                // In PDSetWhiteboardTagOnObject, instead of GetFunctionByName on wb,
                // find SetTagFloat via the class hierarchy iteration
                UFunction* setTagFunc = nullptr;
                UClass* cls = wb->GetClassPrivate();
                while (cls && !setTagFunc)
                {
                    for (UFunction* func : cls->ForEachFunction())
                    {
                        if (func && func->GetName() == STR("SetTagFloat"))
                        {
                            setTagFunc = func;
                            break;
                        }
                    }
                    cls = static_cast<UClass*>(cls->GetSuperStruct());
                }


                struct FGameplayTag { FName TagName; };

                struct SetTagParams
                {
                    FGameplayTag tag;
                    float value;
                };
                SetTagParams params{};
                params.tag = FGameplayTag{ FName(tagStr.c_str()) };
                params.value = value;

                if (!setTagFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetWhiteboardTagOnObject: SetTagFloat not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }
                wb->ProcessEvent(setTagFunc, &params);
                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDGetObjectPath", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (!lua_isuserdata(L, 1)) { lua_pushnil(L); return 1; }

                UObject* obj = *static_cast<UObject**>(lua_touserdata(L, 1));
                if (!obj) { lua_pushnil(L); return 1; }

                try
                {
                    auto fullName = obj->GetFullName();
                    // fullName is RC::StringType which is std::wstring
                    auto spacePos = fullName.find(L' ');
                    if (spacePos != std::wstring::npos)
                    {
                        auto path = fullName.substr(spacePos + 1);
                        auto str = std::string(path.begin(), path.end());
                        lua_pushstring(L, str.c_str());
                    }
                }
                catch (...)
                {
                    lua_pushnil(L);
                }
                return 1;
            });

        lua.register_function("PDShowInventoryMessage", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* msgUtf8 = lua_tostring(L, 1);
                const char* fmPathUtf8 = lua_tostring(L, 2);

                std::wstring msgWide(msgUtf8, msgUtf8 + strlen(msgUtf8));
                std::wstring fmPath(fmPathUtf8, fmPathUtf8 + strlen(fmPathUtf8));

                UObject* fm = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, fmPath.c_str());

                if (!fm)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                UFunction* func = fm->GetFunctionByName(STR("ShowInventoryMessage"));
                if (!func)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct ShowParams
                {
                    FText inText;
                    UObject* sfxOverride{ nullptr };
                };

                ShowParams params{ FText(msgWide.c_str()), nullptr };
                fm->ProcessEvent(func, &params);

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDAddHistoryText", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* textUtf8 = lua_tostring(L, 1);
                const char* pathUtf8 = lua_tostring(L, 2);
                std::wstring textWide(textUtf8, textUtf8 + strlen(textUtf8));
                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDAddHistoryText: object not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                UFunction* func = obj->GetFunctionByName(STR("AddHistoryText"));
                if (!func)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDAddHistoryText: function not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct AddHistoryTextParams
                {
                    FText    text;
                    uint8_t  font[104];
                    UObject* listEntry;
                };
                static_assert(sizeof(AddHistoryTextParams) == 136, "params size wrong");

                AddHistoryTextParams params{};
                params.text = FText(textWide.c_str());
                memset(params.font, 0, 104);
                params.listEntry = nullptr;

                // Optional third arg: font source path, fourth arg: offset (default 0x240)
                /*if (lua_gettop(L) >= 3 && lua_isstring(L, 3))
                {
                    const char* srcUtf8 = lua_tostring(L, 3);
                    std::wstring srcPath(srcUtf8, srcUtf8 + strlen(srcUtf8));
                    UObject* fontSrc = UObjectGlobals::StaticFindObject<UObject*>(
                        nullptr, nullptr, srcPath.c_str());
                    if (fontSrc)
                    {
                        int offset = 0x240;
                        if (lua_gettop(L) >= 4 && lua_isinteger(L, 4))
                            offset = (int)lua_tointeger(L, 4);
                        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddHistoryText: stealing font at 0x{:X}\n"), offset);
                        memcpy(params.font, reinterpret_cast<uint8_t*>(fontSrc) + offset, 104);
                    }
                }*/
                // Don't steal font at all, just hardcode the FName from live instance dumps
// 0x248 relative to object = offset +0x08 within FSlateFontInfo (after null FontObject)
                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddHistoryText: writing hardcoded font\n"));
                memset(params.font, 0, 104);
                *reinterpret_cast<uint64_t*>(params.font + 0x48) = 0x000039ED0001A315ULL;
                *reinterpret_cast<float*>(params.font + 0x50) = 24.0f;
                *reinterpret_cast<uint64_t*>(params.font + 0x10) = 0x000048930001BB80ULL;
                *reinterpret_cast<uint64_t*>(params.font + 0x18) = 0x000048930001BB80ULL;
                // Try writing font size = 24.0f at offset +0x48

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddHistoryText: calling ProcessEvent\n"));
                obj->ProcessEvent(func, &params);
                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddHistoryText: done\n"));

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDCallFunctionNoReturn", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* objPathUtf8 = lua_tostring(L, 1);
                const char* funcNameUtf8 = lua_tostring(L, 2);
                std::wstring objPath(objPathUtf8, objPathUtf8 + strlen(objPathUtf8));
                std::wstring funcName(funcNameUtf8, funcNameUtf8 + strlen(funcNameUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                UFunction* func = obj->GetFunctionByName(funcName.c_str());
                if (!func) { lua_pushboolean(L, false); return 1; }

                // Optional third arg: UObject* param
                if (lua_gettop(L) >= 3 && lua_isstring(L, 3))
                {
                    const char* paramPathUtf8 = lua_tostring(L, 3);
                    std::wstring paramPath(paramPathUtf8, paramPathUtf8 + strlen(paramPathUtf8));

                    struct SoftClassParams
                    {
                        FWeakObjectPtr weakPtr;      // 8 bytes
                        int32_t        tagAtLastTest; // 4 bytes
                        int32_t        pad;           // 4 bytes
                        FName          assetPathName; // 8 bytes
                        wchar_t* strData;       // 8 bytes (FString ptr)
                        int32_t        strLen;        // 4 bytes
                        int32_t        strMax;        // 4 bytes
                        uint8_t        extra[8];      // 8 bytes padding to reach 48
                    };
                    static_assert(sizeof(SoftClassParams) == 48, "SoftClassParams size wrong");

                    SoftClassParams params{};
                    params.assetPathName = FName(paramPath.c_str());
                    Output::send<LogLevel::Verbose>(STR("[PDCmdMod] SoftClass FName: {}\n"), params.assetPathName.ToString());
                    // WeakPtr, tag, SubPathString all zero = unloaded but valid path

                    obj->ProcessEvent(func, &params);
                    lua_pushboolean(L, true);
                    return 1;
                }

                // No param version
                obj->ProcessEvent(func, nullptr);
                lua_pushboolean(L, true);
                return 1;
            });



        lua.register_function("PDWriteFloat", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 3 || !lua_isstring(L, 1))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* pathUtf8 = lua_tostring(L, 1);
                int offset = (int)lua_tointeger(L, 2);
                float value = (float)lua_tonumber(L, 3);

                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));
                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                *reinterpret_cast<float*>(reinterpret_cast<uint8_t*>(obj) + offset) = value;
                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDReadFloat", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* pathUtf8 = lua_tostring(L, 1);
                int offset = (int)lua_tointeger(L, 2);

                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));
                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                float value = *reinterpret_cast<float*>(reinterpret_cast<uint8_t*>(obj) + offset);
                lua_pushnumber(L, value);
                return 1;
            });

        lua.register_function("PDAddFadingHistoryText", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* textUtf8 = lua_tostring(L, 1);
                const char* pathUtf8 = lua_tostring(L, 2);
                std::wstring textWide(textUtf8, textUtf8 + strlen(textUtf8));
                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDAddFadingHistoryText: object not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                UFunction* func = obj->GetFunctionByName(STR("AddFadingHistoryWidgetByText"));
                if (!func)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDAddFadingHistoryText: function not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct AddFadingHistoryParams
                {
                    FText    text;
                    uint8_t  font[104];
                    UObject* listEntry;
                    UObject* callFuncEntry;
                };
                static_assert(sizeof(AddFadingHistoryParams) == 144, "params size wrong");

                FText persistentText = FText(textWide.c_str());

                AddFadingHistoryParams params{};
                params.text = persistentText;  // copy after construction
                memset(params.font, 0, 104);
                params.listEntry = nullptr;
                params.callFuncEntry = nullptr;
                
                // Optional third arg: font source path, optional fourth arg: offset (default 0x240)
                if (lua_gettop(L) >= 3 && lua_isstring(L, 3))
                {
                    const char* srcUtf8 = lua_tostring(L, 3);
                    std::wstring srcPath(srcUtf8, srcUtf8 + strlen(srcUtf8));
                    UObject* fontSrc = UObjectGlobals::StaticFindObject<UObject*>(
                        nullptr, nullptr, srcPath.c_str());
                    if (fontSrc)
                    {
                        int offset = 0x240;
                        if (lua_gettop(L) >= 4 && lua_isinteger(L, 4))
                            offset = (int)lua_tointeger(L, 4);
                        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddFadingHistoryText: stealing font at 0x{:X}\n"), offset);
                        memcpy(params.font, reinterpret_cast<uint8_t*>(fontSrc) + offset, 104);
                    }
                }

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddFadingHistoryText: calling ProcessEvent\n"));
                obj->ProcessEvent(func, &params);
                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDAddFadingHistoryText: done\n"));

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDScanFontOffset", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                const char* pathUtf8 = lua_tostring(L, 1);
                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                // Find bedstead font object
                UObject* font = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, STR("/Game/UI/Fonts/Faces/bedstead.bedstead"));
                if (!font)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDScanFontOffset: font not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Font UObject: {:p}\n"), (void*)font);

                // Scan object memory for the font pointer
                uint8_t* base = reinterpret_cast<uint8_t*>(obj);
                for (int offset = 0x100; offset < 0x500; offset += 8)
                {
                    UObject** candidate = reinterpret_cast<UObject**>(base + offset);
                    if (*candidate == font)
                    {
                        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] Found font pointer at offset: 0x{:X}\n"), offset);
                    }
                }

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDDumpOffsets", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                const char* pathUtf8 = lua_tostring(L, 1);
                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));
                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                int startOffset = 0x100;
                int endOffset = 0x600;
                if (lua_gettop(L) >= 2 && lua_isinteger(L, 2))
                    startOffset = (int)lua_tointeger(L, 2);
                if (lua_gettop(L) >= 3 && lua_isinteger(L, 3))
                    endOffset = (int)lua_tointeger(L, 3);

                uint8_t* base = reinterpret_cast<uint8_t*>(obj);
                for (int offset = startOffset; offset < endOffset; offset += 8)
                {
                    uint64_t val = *reinterpret_cast<uint64_t*>(base + offset);
                    Output::send<LogLevel::Verbose>(
                        STR("[0x{:X}] {:016X}\n"), offset, val);
                }
                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDSetFText", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 3 || !lua_isstring(L, 1) || !lua_isstring(L, 2) || !lua_isstring(L, 3))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* pathUtf8 = lua_tostring(L, 1);
                const char* propUtf8 = lua_tostring(L, 2);
                const char* textUtf8 = lua_tostring(L, 3);

                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));
                std::wstring propName(propUtf8, propUtf8 + strlen(propUtf8));
                std::wstring textWide(textUtf8, textUtf8 + strlen(textUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj)
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                FTextProperty* prop = static_cast<FTextProperty*>(
                    obj->GetClassPrivate()->FindProperty(FName(propName.c_str())));
                if (!prop)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetFText: property not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                FText* textPtr = prop->ContainerPtrToValuePtr<FText>(obj);
                *textPtr = FText(textWide.c_str());

                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDSetSlotSize", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 3 || !lua_isstring(L, 1))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* pathUtf8 = lua_tostring(L, 1);
                float x = (float)lua_tonumber(L, 2);
                float y = (float)lua_tonumber(L, 3);
                std::wstring objPath(pathUtf8, pathUtf8 + strlen(pathUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                UFunction* func = obj->GetFunctionByName(STR("SetSize"));
                if (!func)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetSlotSize: SetSize not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct SetSizeParams
                {
                    float X;
                    float Y;
                };
                SetSizeParams params{ x, y };
                obj->ProcessEvent(func, &params);

                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDCallWithFText", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                if (lua_gettop(L) < 3 || !lua_isstring(L, 1) || !lua_isstring(L, 2) || !lua_isstring(L, 3))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* objPathUtf8 = lua_tostring(L, 1);
                const char* funcNameUtf8 = lua_tostring(L, 2);
                const char* textUtf8 = lua_tostring(L, 3);

                std::wstring objPath(objPathUtf8, objPathUtf8 + strlen(objPathUtf8));
                std::wstring funcName(funcNameUtf8, funcNameUtf8 + strlen(funcNameUtf8));
                std::wstring textWide(textUtf8, textUtf8 + strlen(textUtf8));

                UObject* obj = UObjectGlobals::StaticFindObject<UObject*>(
                    nullptr, nullptr, objPath.c_str());
                if (!obj) { lua_pushboolean(L, false); return 1; }

                UFunction* func = obj->GetFunctionByName(funcName.c_str());
                if (!func) { lua_pushboolean(L, false); return 1; }

                // Single FText parameter
                struct Params { FText text; };
                Params params{ FText(textWide.c_str()) };
                obj->ProcessEvent(func, &params);

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDRemoveHandItem", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                // Find BFL CDO
                UObject* bfl = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr,
                    STR("/Game/Systems/ScriptingLibraries/BFL_InventorySlotUtils.Default__BFL_InventorySlotUtils_C"));
                if (!bfl) { lua_pushboolean(L, false); return 1; }

                // Find InventoryManager
                UObject* im = nullptr;
                UObjectGlobals::ForEachUObject([&](UObject* obj, ...) {
                    if (!im && obj && obj->GetClassPrivate())
                    {
                        auto name = obj->GetClassPrivate()->GetName();
                        if (name == STR("BP_InventoryManager_C")) im = obj;
                    }
                    return RC::LoopAction::Continue;
                    });
                if (!im) { lua_pushboolean(L, false); return 1; }

                // Find world context
                UObject* ctx = nullptr;
                UObjectGlobals::ForEachUObject([&](UObject* obj, ...) {
                    if (!ctx && obj && obj->GetClassPrivate())
                    {
                        auto name = obj->GetClassPrivate()->GetName();
                        if (name == STR("BP_UIManager_C")) ctx = obj;
                    }
                    return RC::LoopAction::Continue;
                    });
                if (!ctx) { lua_pushboolean(L, false); return 1; }

                // Get hand slot via GetHandSlot
                UFunction* getHandSlotFunc = im->GetFunctionByName(STR("GetHandSlot"));
                if (!getHandSlotFunc) { lua_pushboolean(L, false); return 1; }

                struct GetHandSlotParams
                {
                    UObject* HandSlot;
                    UObject* HandContainer;
                };
                GetHandSlotParams handParams{};
                im->ProcessEvent(getHandSlotFunc, &handParams);

                UObject* handSlot = handParams.HandSlot;
                if (!handSlot)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDRemoveHandItem: no hand slot\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Get ItemInstance from hand slot — try ItemInstance property
                UObject* instance = nullptr;
                FProperty* instProp = handSlot->GetClassPrivate()->FindProperty(FName(STR("ItemInstance")));
                if (instProp)
                {
                    instance = *instProp->ContainerPtrToValuePtr<UObject*>(handSlot);
                }
                if (!instance)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDRemoveHandItem: no item instance\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Call RemoveItem(Instance, WorldContext, out Removed)
                UFunction* removeFunc = bfl->GetFunctionByName(STR("RemoveItem"));
                if (!removeFunc) { lua_pushboolean(L, false); return 1; }

                struct RemoveItemParams
                {
                    UObject* Instance;
                    UObject* WorldContext;
                    bool     Removed;
                    bool     Success;
                };

                RemoveItemParams removeParams{};
                removeParams.Instance = instance;
                removeParams.WorldContext = ctx;
                removeParams.Removed = false;
                removeParams.Success = false;

                bfl->ProcessEvent(removeFunc, &removeParams);

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDRemoveHandItem: Removed={} Success={}\n"),
                    removeParams.Removed, removeParams.Success);

                lua_pushboolean(L, removeParams.Removed);
                return 1;
            });

        lua.register_function("PDSetGlobalWhiteboardTag", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isnumber(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* tagUtf8 = lua_tostring(L, 1);
                float value = (float)lua_tonumber(L, 2);
                std::wstring tagStr(tagUtf8, tagUtf8 + strlen(tagUtf8));

                // Find ProgressionManager
                UObject* pm = nullptr;
                UObjectGlobals::ForEachUObject([&](UObject* obj, int32 chunkIdx, int32 objIdx) {
                    if (!pm && obj && obj->GetClassPrivate() &&
                        obj->GetClassPrivate()->GetName() == STR("BP_ProgressionManager_C"))
                        pm = obj;
                    return RC::LoopAction::Continue;
                    });
                if (!pm)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetGlobalWhiteboardTag: PM not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Call GetGlobalWhiteboard(pm) — pass pm as world context
                UFunction* getWbFunc = pm->GetFunctionByName(STR("GetGlobalWhiteboard"));
                if (!getWbFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetGlobalWhiteboardTag: GetGlobalWhiteboard not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct GetWbParams { UObject* WorldContext; UObject* ReturnValue; };
                GetWbParams wbParams{ pm, nullptr };
                pm->ProcessEvent(getWbFunc, &wbParams);

                UObject* wb = wbParams.ReturnValue;
                if (!wb)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetGlobalWhiteboardTag: whiteboard null\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Call SetTagFloat directly on whiteboard
                UFunction* setTagFunc = wb->GetFunctionByName(STR("SetTagFloat"));
                if (!setTagFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetGlobalWhiteboardTag: SetTagFloat not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                struct FGameplayTag { FName TagName; };
                struct SetTagParams { FGameplayTag Tag; float Value; };
                SetTagParams params{ FGameplayTag{ FName(tagStr.c_str()) }, value };
                wb->ProcessEvent(setTagFunc, &params);

                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDSetInputModeUIOnly", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                // Find GameplayStatics CDO - this has the Blueprint-exposed SetInputMode functions
                UObject* gps = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr,
                    STR("/Script/Engine.Default__GameplayStatics"));
                if (!gps)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetInputModeUIOnly: GameplayStatics not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find player controller
                UObject* pc = nullptr;
                UObjectGlobals::ForEachUObject([&](UObject* obj, int32 chunkIdx, int32 objIdx) {
                    if (!pc && obj && obj->GetClassPrivate())
                    {
                        auto name = obj->GetClassPrivate()->GetName();
                        if (name.find(STR("PlayerController")) != std::wstring::npos &&
                            name != STR("PlayerController"))  // skip base class CDO
                            pc = obj;
                    }
                    return RC::LoopAction::Continue;
                    });
                if (!pc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetInputModeUIOnly: PC not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                bool uiOnly = true;
                if (lua_gettop(L) >= 1 && lua_isboolean(L, 1))
                    uiOnly = lua_toboolean(L, 1);

                if (uiOnly)
                {
                    UFunction* func = gps->GetFunctionByName(STR("SetInputMode_UIOnlyEx"));
                    if (!func) func = gps->GetFunctionByName(STR("SetInputMode_UIOnly"));
                    if (func)
                    {
                        struct SetInputModeUIOnlyParams
                        {
                            UObject* PlayerController;
                            UObject* InWidgetToFocus; // nullptr = no specific widget
                            uint8_t  InMouseLockMode; // EMouseLockMode, 1 = LockOnCapture
                            bool     bFlushInput;
                        };
                        SetInputModeUIOnlyParams params{ pc, nullptr, 1, true };
                        gps->ProcessEvent(func, &params);
                        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDSetInputModeUIOnly: UI mode set\n"));
                    }
                    else
                    {
                        Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDSetInputModeUIOnly: function not found\n"));
                        lua_pushboolean(L, false);
                        return 1;
                    }
                }
                else
                {
                    UFunction* func = gps->GetFunctionByName(STR("SetInputMode_GameOnly"));
                    if (func)
                    {
                        struct SetInputModeGameOnlyParams { UObject* PlayerController; };
                        SetInputModeGameOnlyParams params{ pc };
                        gps->ProcessEvent(func, &params);
                        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDSetInputModeUIOnly: Game mode restored\n"));
                    }
                }

                lua_pushboolean(L, true);
                return 1;
            });

        lua.register_function("PDCreateAndShowWidget", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }

                const char* widgetPathUtf8 = lua_tostring(L, 1);
                const char* pcPathUtf8 = lua_tostring(L, 2);
                std::wstring widgetPath(widgetPathUtf8, widgetPathUtf8 + strlen(widgetPathUtf8));
                std::wstring pcPath(pcPathUtf8, pcPathUtf8 + strlen(pcPathUtf8));

                // Find widget class (must be pre-loaded via LoadAsset from Lua)
                UObject* widgetClass = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, widgetPath.c_str());
                if (!widgetClass)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateAndShowWidget: widget class not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find player controller
                UObject* pc = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, pcPath.c_str());
                if (!pc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateAndShowWidget: PC not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find WBL CDO
                UObject* wbl = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr,
                    STR("/Script/UMG.Default__WidgetBlueprintLibrary"));
                if (!wbl)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateAndShowWidget: WBL not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Find Create function
                UFunction* createFunc = wbl->GetFunctionByName(STR("Create"));
                if (!createFunc)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateAndShowWidget: Create not found\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // Call WBL::Create(WorldContext, WidgetType, OwningPlayer) -> UserWidget
                struct CreateParams
                {
                    UObject* WorldContext;
                    UObject* WidgetType;
                    UObject* OwningPlayer;
                    UObject* ReturnValue;
                };
                CreateParams createParams{ pc, widgetClass, pc, nullptr };
                wbl->ProcessEvent(createFunc, &createParams);

                UObject* widget = createParams.ReturnValue;
                if (!widget)
                {
                    Output::send<LogLevel::Warning>(STR("[PDCmdMod] PDCreateAndShowWidget: Create returned null\n"));
                    lua_pushboolean(L, false);
                    return 1;
                }

                // In PDCreateAndShowWidget, after creation:
                s_lastCreatedWidget = widget;
                lua_pushboolean(L, true);
                return 1;
            });


        lua.register_function("PDSetLegWhiteboardTags", [](const LuaMadeSimple::Lua& lua) -> int
            {
                lua_State* L = lua.get_lua_state();

                // Get tag name and value from Lua
                if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isnumber(L, 2))
                {
                    lua_pushboolean(L, false);
                    return 1;
                }
                const char* tagUtf8 = lua_tostring(L, 1);
                float value = (float)lua_tonumber(L, 2);
                std::wstring tagStr(tagUtf8, tagUtf8 + strlen(tagUtf8));

                int count = 0;

                UObjectGlobals::ForEachUObject([&](UObject* obj, int32 chunkIdx, int32 objIdx) {
                    if (!obj || !obj->GetClassPrivate()) return RC::LoopAction::Continue;

                    auto className = obj->GetClassPrivate()->GetName();
                    if (className != STR("BP_LegState_C") &&
                        className != STR("BP_LegStateBase_C"))
                        return RC::LoopAction::Continue;

                    // Call GetLegWhiteboard on this leg
                    UFunction* getWbFunc = obj->GetFunctionByName(STR("GetLegWhiteboard"));
                    if (!getWbFunc) return RC::LoopAction::Continue;

                    struct GetWbParams { UObject* ReturnValue; };
                    GetWbParams wbParams{ nullptr };
                    obj->ProcessEvent(getWbFunc, &wbParams);

                    UObject* wb = wbParams.ReturnValue;
                    if (!wb) return RC::LoopAction::Continue;

                    // Call SetTagFloat on whiteboard
                    UFunction* setTagFunc = wb->GetFunctionByName(STR("SetTagFloat"));
                    if (!setTagFunc) return RC::LoopAction::Continue;

                    struct FGameplayTag { FName TagName; };
                    struct SetTagParams { FGameplayTag Tag; float Value; };
                    SetTagParams params{ FGameplayTag{ FName(tagStr.c_str()) }, value };
                    wb->ProcessEvent(setTagFunc, &params);
                    count++;

                    return RC::LoopAction::Continue;
                    });

                Output::send<LogLevel::Verbose>(STR("[PDCmdMod] PDSetLegWhiteboardTags: set {} legs\n"), count);
                lua_pushinteger(L, count);
                return 1;
            });


        Output::send<LogLevel::Verbose>(STR("[PDCmdMod] C++ Functions registered.\n"));
    }


};

#define MOD_EXPORT __declspec(dllexport)
extern "C"
{
    MOD_EXPORT RC::CppUserModBase* start_mod()
    {
        return new PDCmdMod();
    }

    MOD_EXPORT void uninstall_mod(RC::CppUserModBase* mod)
    {
        delete mod;
    }
}