using AutoMapper;

namespace eToro.Trading.{ServiceName}.WebApi.Mapper;

public sealed class {Feature}MappingProfile : Profile
{
    public {Feature}MappingProfile()
    {
        CreateMap<{Feature}Entity, {Feature}Item>()
            .ForMember(dest => dest.Id, opt => opt.MapFrom(src => src.{Feature}Id))
            .ForMember(dest => dest.Name, opt => opt.MapFrom(src => src.Name))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status));
    }
}
