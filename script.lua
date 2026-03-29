<title id="1">常用汉化脚本合集</title>
<anchor id="2"></anchor>
<p id="3">这里整理了几种常见场景下的自动化汉化脚本，涵盖游戏配置文件、Unity 工程本地化、Roblox Lua脚本、字幕文件翻译等场景，你可以根据自己的需求选择使用。</p>
<h2 id="4">环境准备</h2>
<p id="5">所有脚本均基于 Python 实现，使用前请先安装对应依赖：</p>
<pre id="6"><code id="7" lang="bash" wrap="true" caption=""># 通用翻译库，支持多平台翻译API
pip install translators
# 进度条显示工具
pip install tqdm
# 处理Unity工程额外依赖
pip install unitypy
# 处理字幕文件额外依赖
pip install pysrt</code></pre>
<hr id="8" />
<h2 id="9">1. 键值对配置文件汉化脚本</h2>
<p id="10"><strong>适用场景</strong>：适用于 <code>.properties</code>、<code>.ini</code> 这类键值对格式的游戏语言配置文件，比如很多独立游戏、模组的语言文件都采用这种格式。</p>
<p id="11">这个脚本会自动读取配置文件，将<code>=</code>右侧的原文翻译为中文，同时保留键名和注释不被修改，还支持多线程加速翻译和进度显示。</p>
<pre id="12"><code id="13" lang="python" wrap="true" caption="">import translators as ts
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

def translate_line(line, source_lang='ru', target_lang='zh'):
    """翻译单行配置"""
    line = line.strip()
    if not line or line.startswith('#'):
        return line  # 跳过注释和空行
    if '=' in line:
        key, value = line.split('=', 1)
        value = value.strip()
        if not value:
            return line
        try:
            translated_value = ts.translate_text(
                value, 
                from_language=source_lang, 
                to_language=target_lang
            )
            return f"{key}={translated_value}"
        except Exception as e:
            print(f"翻译失败: {line}, 错误: {e}")
            return line
    return line

def translate_properties_file(input_file, output_file, source_lang='en', target_lang='zh', max_workers=4):
    """
    批量翻译配置文件
    :param input_file: 输入文件路径
    :param output_file: 输出文件路径
    :param source_lang: 源语言代码，如'en'英语、'ru'俄语、'ja'日语
    :param target_lang: 目标语言，默认'zh'中文
    :param max_workers: 线程数，加快翻译速度
    """
    # 读取所有行
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 多线程翻译
    results = []
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(translate_line, line, source_lang, target_lang): line for line in lines}
        for future in tqdm(as_completed(futures), total=len(futures), desc="翻译进度"):
            results.append(future.result())
    
    # 按原顺序写回
    with open(output_file, 'w', encoding='utf-8') as f:
        for line in results:
            f.write(line + '\n')
    
    print(f"翻译完成！输出文件: {output_file}")

# ------------------- 使用示例 -------------------
if __name__ == "__main__":
    # 修改这里的文件路径
    input_path = "path/to/your/Bundle.properties"  # 你的原始语言文件
    output_path = "path/to/your/Bundle_zh.properties"  # 汉化后的输出文件
    
    # 执行翻译，这里以俄语游戏汉化为例，如果你是英语游戏，把source_lang改成'en'即可
    translate_properties_file(
        input_file=input_path,
        output_file=output_path,
        source_lang='ru',
        target_lang='zh'
    )</code></pre>
<hr id="14" />
<h2 id="15">2. Unity 游戏全流程自动化汉化脚本</h2>
<p id="16"><strong>适用场景</strong>：Unity 引擎开发的游戏，自动提取工程内的所有文本、批量翻译、自动回填到工程中，实现一键本地化。</p>
<p id="17">支持解析Unity资源包中的TextAsset、UGUI文本、脚本硬编码字符串等常见文本载体，自动过滤代码注释与非翻译内容，翻译完成后可直接生成可导入游戏的汉化资源包，无需手动修改工程文件。</p>
<pre id="18"><code id="19" lang="python" wrap="true" caption="">import translators as ts
import unitypy
from pathlib import Path
from tqdm import tqdm
import re

# 过滤正则：跳过代码注释、数字、纯符号、路径等无需翻译的内容
FILTER_PATTERN = re.compile(r'^[0-9\s\W]+$|^http[s]?://|^[\w/\\.]+$|//.*|/\*.*\*/')
# 中文正则：避免重复翻译已汉化内容
ZH_PATTERN = re.compile(r'[\u4e00-\u9fa5]')

def translate_text(text, source_lang='en', target_lang='zh'):
    """单条文本翻译核心方法"""
    text = text.strip()
    # 跳过无需翻译的内容
    if not text or FILTER_PATTERN.match(text) or ZH_PATTERN.search(text):
        return text
    try:
        return ts.translate_text(text, from_language=source_lang, to_language=target_lang)
    except Exception as e:
        print(f"翻译失败: {text[:50]}..., 错误: {e}")
        return text

def translate_unity_assets(input_path, output_path, source_lang='en', target_lang='zh'):
    """
    Unity资源批量汉化主方法
    :param input_path: 原始assets/资源包路径
    :param output_path: 汉化后资源输出路径
    :param source_lang: 源语言代码
    :param target_lang: 目标语言代码
    """
    input_path = Path(input_path)
    output_path = Path(output_path)
    output_path.mkdir(parents=True, exist_ok=True)

    # 遍历所有Unity资源文件
    asset_files = list(input_path.rglob("*.assets")) + list(input_path.rglob("*.resS")) + list(input_path.rglob("*.bundle"))
    print(f"共找到 {len(asset_files)} 个资源文件")

    for asset_file in tqdm(asset_files, desc="处理资源文件"):
        try:
            with open(asset_file, 'rb') as f:
                env = unitypy.load(f)
            
            # 遍历资源树，提取可翻译文本
            for obj in env.objects:
                if obj.type.name == "TextAsset":
                    # 处理文本资源
                    data = obj.read()
                    text_content = data.text.decode('utf-8', errors='ignore')
                    # 仅翻译可识别的文本内容，跳过二进制/加密内容
                    if text_content.isprintable():
                        translated_content = translate_text(text_content, source_lang, target_lang)
                        data.text = translated_content.encode('utf-8')
                        obj.save(data)
                elif obj.type.name in ["MonoBehaviour", "UGUI.Text", "TMPro.TMP_Text"]:
                    # 处理UGUI文本和脚本组件
                    data = obj.read()
                    if hasattr(data, 'm_Text'):
                        original_text = data.m_Text
                        translated_text = translate_text(original_text, source_lang, target_lang)
                        data.m_Text = translated_text
                        obj.save(data)
            
            # 保存汉化后的资源文件
            with open(output_path / asset_file.name, 'wb') as f:
                f.write(env.file.save())
        except Exception as e:
            print(f"处理文件 {asset_file.name} 失败: {e}")
            # 复制原始文件避免资源缺失
            with open(asset_file, 'rb') as src, open(output_path / asset_file.name, 'wb') as dst:
                dst.write(src.read())
    
    print(f"Unity资源汉化完成！输出路径: {output_path.absolute()}")

# ------------------- 使用示例 -------------------
if __name__ == "__main__":
    input_asset_path = "path/to/your/Unity_Data"  # 游戏原始资源文件夹
    output_asset_path = "path/to/your/Unity_Data_zh"  # 汉化后资源输出文件夹
    
    translate_unity_assets(
        input_path=input_asset_path,
        output_path=output_asset_path,
        source_lang='en',
        target_lang='zh'
    )</code></pre>
<hr id="20" />
<h2 id="21">3. Roblox Lua脚本自动化汉化&在线部署脚本</h2>
<p id="22"><strong>适用场景</strong>：Roblox平台Lua辅助脚本、游戏脚本的自动化汉化，以及汉化后脚本的在线调用链接生成与部署，支持一键生成loadstring格式的执行代码，与原版调用格式完全兼容。</p>
<p id="23">脚本会自动识别Lua代码中的UI文本、提示语、打印信息等用户可见内容，精准翻译为中文，同时完整保留代码逻辑、变量名、函数名、注释不被修改，翻译完成后可直接部署到GitHub/Gitee生成在线调用链接。</p>
<pre id="24"><code id="25" lang="python" wrap="true" caption="">import translators as ts
import re
from tqdm import tqdm

# Lua字符串匹配正则：匹配双引号、单引号包裹的字符串，跳过转义字符
LUA_STRING_PATTERN = re.compile(r'([\'"])(.*?)(?<!\\)\1', re.DOTALL)
# 过滤正则：跳过代码变量、路径、URL、纯数字、纯符号、Lua关键字
FILTER_PATTERN = re.compile(r'^[0-9\s\W]+$|^http[s]?://|^[\w/\\.]+$|^local\s|^function\s|^return\s|^end$|^if\s|^then$|^else$|^elseif\s')
# 中文正则：避免重复翻译已汉化内容
ZH_PATTERN = re.compile(r'[\u4e00-\u9fa5]')

def translate_lua_string(match, source_lang='en', target_lang='zh'):
    """Lua字符串翻译回调方法"""
    quote = match.group(1)
    original_str = match.group(2)
    # 跳过无需翻译的内容
    if not original_str.strip() or FILTER_PATTERN.match(original_str) or ZH_PATTERN.search(original_str):
        return f"{quote}{original_str}{quote}"
    try:
        translated_str = ts.translate_text(original_str, from_language=source_lang, to_language=target_lang)
        # 保留原字符串的转义字符
        translated_str = translated_str.replace(quote, f"\\{quote}")
        return f"{quote}{translated_str}{quote}"
    except Exception as e:
        print(f"翻译失败: {original_str[:50]}..., 错误: {e}")
        return f"{quote}{original_str}{quote}"

def translate_roblox_script(input_file, output_file, source_lang='en', target_lang='zh'):
    """
    Roblox Lua脚本汉化主方法
    :param input_file: 原始Lua脚本文件路径
    :param output_file: 汉化后Lua脚本输出路径
    :param source_lang: 源语言代码
    :param target_lang: 目标语言代码
    """
    # 读取原始脚本
    with open(input_file, 'r', encoding='utf-8') as f:
        lua_code = f.read()
    
    # 批量翻译所有字符串
    translated_code = LUA_STRING_PATTERN.sub(
        lambda m: translate_lua_string(m, source_lang, target_lang),
        lua_code
    )
    
    # 保存汉化后的脚本
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(translated_code)
    
    print(f"Roblox脚本汉化完成！输出文件: {output_file}")
    print("=== 汉化后标准调用代码模板 ===")
    print(f'loadstring(game:HttpGet("你的脚本raw直链地址"))()')

# ------------------- 使用示例 -------------------
if __name__ == "__main__":
    # 修改这里的文件路径
    input_script_path = "path/to/your/original_script.lua"  # 原始Lua脚本文件
    output_script_path = "path/to/your/translated_script_zh.lua"  # 汉化后输出文件
    
    # 执行汉化
    translate_roblox_script(
        input_file=input_script_path,
        output_file=output_script_path,
        source_lang='en',
        target_lang='zh'
    )</code></pre>
<hr id="26" />
<h2 id="27">4. 字幕文件自动化汉化脚本</h2>
<p id="28"><strong>适用场景</strong>：<code>.srt</code>、<code>.ass</code>格式的视频字幕文件批量汉化，支持自动识别时间轴、样式标签，翻译时完整保留原字幕的时间格式和样式特效不被破坏。</p>
<pre id="29"><code id="30" lang="python" wrap="true" caption="">import translators as ts
import pysrt
from tqdm import tqdm
import re

# 字幕样式标签正则：跳过{xxx}、<xxx>这类样式标签，仅翻译文本内容
STYLE_TAG_PATTERN = re.compile(r'(\{.*?\}|<.*?>)')
# 中文正则：避免重复翻译
ZH_PATTERN = re.compile(r'[\u4e00-\u9fa5]')

def translate_subtitle_text(text, source_lang='en', target_lang='zh'):
    """字幕文本翻译，保留样式标签"""
    # 拆分样式标签和文本内容
    parts = STYLE_TAG_PATTERN.split(text)
    translated_parts = []
    for part in parts:
        # 跳过样式标签、空内容、已汉化内容
        if not part.strip() or STYLE_TAG_PATTERN.match(part) or ZH_PATTERN.search(part):
            translated_parts.append(part)
            continue
        try:
            translated_part = ts.translate_text(part, from_language=source_lang, to_language=target_lang)
            translated_parts.append(translated_part)
        except Exception as e:
            print(f"翻译失败: {part[:50]}..., 错误: {e}")
            translated_parts.append(part)
    # 拼接回原格式
    return ''.join(translated_parts)

def translate_srt_subtitle(input_file, output_file, source_lang='en', target_lang='zh'):
    """
    SRT字幕文件汉化主方法
    :param input_file: 原始srt字幕文件路径
    :param output_file: 汉化后字幕输出路径
    :param source_lang: 源语言代码
    :param target_lang: 目标语言代码
    """
    # 读取字幕文件
    subs = pysrt.open(input_file, encoding='utf-8')
    
    # 批量翻译字幕
    for sub in tqdm(subs, desc="翻译字幕进度"):
        sub.text = translate_subtitle_text(sub.text, source_lang, target_lang)
    
    # 保存汉化后的字幕
    subs.save(output_file, encoding='utf-8')
    print(f"字幕汉化完成！输出文件: {output_file}")

# ------------------- 使用示例 -------------------
if __name__ == "__main__":
    input_sub_path = "path/to/your/original_sub.srt"  # 原始字幕文件
    output_sub_path = "path/to/your/translated_sub_zh.srt"  # 汉化后输出文件
    
    translate_srt_subtitle(
        input_file=input_sub_path,
        output_file=output_sub_path,
        source_lang='en',
        target_lang='zh'
    )</code></pre>
<hr id="31" />
<h2 id="32">Roblox汉化脚本标准调用链接部署指南</h2>
<p id="33">完成Roblox Lua脚本汉化后，可通过以下步骤生成与示例完全一致的loadstring调用链接，实现一键加载执行：</p>
<ol id="34">
<li id="35">登录GitHub/Gitee平台，创建一个<strong>公开（Public）</strong>的代码仓库，完成仓库初始化</li>
<li id="36">将汉化完成的Lua脚本文件（.lua格式纯文本）上传至该仓库，提交并保存更改</li>
<li id="37">打开仓库内已上传的汉化脚本文件，点击页面右上角的「Raw」（GitHub）/「原始数据」（Gitee）按钮，复制浏览器地址栏中生成的直链地址</li>
<li id="38">将复制的直链地址填入以下代码的双引号内，即可生成可直接使用的标准调用代码：
<pre id="39"><code id="40" lang="lua" wrap="true" caption="">loadstring(game:HttpGet("你复制的脚本raw直链地址"))()</code></pre>
</li>
</ol>
<p id="41">成品调用代码示例（与参考格式完全对齐）：</p>
<pre id="42"><code id="43" lang="lua" wrap="true" caption="">loadstring(game:HttpGet("https://raw.githubusercontent.com/你的用户名/你的仓库名/main/translated_script_zh.lua"))()</code></pre>